defmodule Delta.Base do

		defmacro __using__(_opts) do
			quote do
				Module.register_attribute(__MODULE__, :interceptors, accumulate: true)
				Module.register_attribute(__MODULE__, :read, accumulate: false)
				Module.register_attribute(__MODULE__, :writes, accumulate: false)
				@interceptors []
				@writes []
				@read []
				@before_compile Delta.Base

				def start_server(port) do
					Delta.Server.start_link(__MODULE__, port)
				end

				def server_spec(port) do
					import Supervisor.Spec
					supervisor(Delta.Server, [__MODULE__, port])
				end
			end
		end

		defmacro __before_compile__(_env) do
			quote do
				def interceptors, do: Enum.flat_map(@interceptors, &(&1))
				def writes, do: @writes
				def read, do: @read

				def handle_connect(_socket) do
					{:ok, %{user: "anonymous"}}
				end

				def handle_command({"drs.ping", body, _version}, socket, state) do
					{:reply, :os.system_time(:millisecond), state}
				end

				def handle_command({action, body, _version}, data) do
					{:error, %{type: :invalid_command}, data}
				end

				def handle_precommand(cmd, data) do
					{:ok, data}
				end

				def handle_postcommand(cmd, response, data) do
					{:ok, data}
				end

				def handle_disconnect(data) do
				end
			end
		end
end

defmodule Delta do
	@master "delta-master"
	alias Delta.Mutation
	alias Delta.Query
	alias Delta.UUID
	alias Delta.Interceptor
	alias Delta.Watch
	alias Delta.Queue
	alias Delta.Dynamic

	def read_store do
		{Delta.Stores.Memory, {}}
	end

	def write_stores do
		[
			{Delta.Stores.Memory, {}}
		]
	end

	def interceptors do
		[]
	end

	def mutation(mut, user \\ @master) do
		interceptors = interceptors()
		case Interceptor.validate(interceptors, mut, user) do
			nil ->
				prepared = Interceptor.prepare(interceptors, mut, user)

				key = UUID.ascending()
				prepared
				|> Watch.notify(key)

				queued =
					read_store()
					|> Queue.write(prepared, key)
					|> Mutation.combine(prepared)

				Mutation.write(queued, write_stores())

				case Interceptor.commit(interceptors, prepared, user) do
					:ok -> prepared
					nil -> prepared
					error -> error
				end
			error -> error
		end
	end

	def merge(path, data, user \\ @master) do
		Mutation.new
		|> Mutation.merge(path, data)
		|> mutation(user)
	end

	def query(qry, user \\ @master) do
		layers = Query.layers(qry)
		layers
		|> Task.async_stream(fn {path, opts} ->
			{path, opts, query_path(path, opts, user)}
		end, max_concurrency: layers |> Enum.count)
		|> Stream.map(fn {:ok, value} -> value end)
		|> Enum.reduce(Mutation.new, fn {path, opts, data}, collect ->
			collect
			|> Dynamic.put([:merge | path], data)
			|> query_response(path, opts)
		end)
	end

	defp query_response(mutation, path, opts) do
		cond do
			opts === %{} ->
				mutation
				|> Dynamic.put([:delete | path], 1)
			true -> mutation
		end
	end

	def query_path(path, opts \\ %{}, user \\ @master) do
		case interceptors() |> Interceptor.resolve(path, user, opts) do
			nil -> Query.path(read_store(), path, opts)
			result -> result
		end
	end
end

defmodule Delta.Sample do
	use Delta.Base
	use Delta.Plugin.Mutation
	use Delta.Plugin.Query
	use Delta.Plugin.Watch
	use Delta.Plugin.Fact

	@interceptors [
		Delta.Sample.Interceptor
	]

	@read {Delta.Stores.Cassandra, []}

	@writes [
		{Delta.Stores.Cassandra, []}
	]

	def sample_fact do
		query_fact([
			[:from, :package],
			[:account, "user:key", "0NeFW0nMZdLlqp80B2HW"],
			[:account, "context:type", "contextio"],
			[:account, "email:key", :email],
			[:email, "email:from", :from],
			[:package, "package:email", :email],
		])
	end

end

defmodule Delta.Sample.Interceptor do
	use Delta.Interceptor

	def intercept_write([], _user, _atom, _mutation) do
		:ok
	end

	def intercept_commit([], _user, _atom, _mutation) do
		:ok
	end

end
