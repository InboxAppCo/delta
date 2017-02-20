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
				def writes, do: @writes || []
				def read, do: @read || []

				def handle_connect(_socket) do
					{:ok, %{user: "anonymous"}}
				end

				def handle_command("drs.ping", _, state) do
					{:reply, :os.system_time(:millisecond), state}
				end

				def handle_command(action, body, data) do
					{:error, "Unknown command #{action}", data}
				end

				def handle_disconnect(data) do
				end
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
