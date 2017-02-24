defmodule Delta.Plugin.Watch do
	defmacro __using__(_opts) do
		alias Delta.Watch
		alias Delta.Dynamic
		alias Delta.Server.Processor
		alias Delta.Mutation

		quote do

			@interceptors [
				Delta.Interceptor.Watch
			]

			def watch(path) do
				Watch.watch(path)
			end

			def unwatch(path) do
				Watch.unwatch(path)
			end

			def handle_info({:mutation, key, mutation = %{merge: merge, delete: delete}}, socket, data) do
				mutation
				|> Mutation.deliver(interceptors(), data.user)

				"delta.mutation"
				|> Processor.format_cmd(%{
					"$merge": merge,
					"$delete": delete,
				}, 1, key)
				|> Processor.send_raw(socket)

				{:ok, data}
			end

			def handle_command({"delta.subscribe", body, _version}, socket, state = %{user: user}) do
				["user:watch:online", user]
				|> query_path
				|> Map.keys
				|> Stream.map(&String.split(&1, "/"))
				|> Enum.each(&watch/1)
				watch(["user:watch:online", user])
				{:reply, true, state}
			end

			def handle_command({"delta.watch", body, _version}, socket, state) do
				body
				|> Dynamic.flatten
				|> Enum.each(fn {path, _} -> watch(path) end)
				{:reply, true, state}
			end

			def handle_command({"delta.unwatch", body, _version}, socket, state) do
				body
				|> Dynamic.flatten
				|> Enum.each(fn {path, _} -> unwatch(path) end)
				{:reply, true, state}
			end
		end
	end
end

defmodule Delta.Interceptor.Watch do
	use Delta.Interceptor
	alias Delta.Mutation
	alias Delta.Watch

	def intercept_delivery(["user:watch:online", _target], _user, atom, _mutation) do
		atom.merge
		|> Map.keys
		|> Stream.map(&String.split(&1, "/"))
		|> Enum.each(&Watch.watch(&1))

		atom.delete
		|> Map.keys
		|> Stream.map(&String.split(&1, "/"))
		|> Enum.each(&Watch.unwatch(&1))
		:ok
	end

	def intercept_write(["user:watch:offline", user], _user, atom, mutation) do
		mutation =
			Map.get(atom, :merge, %{})
			|> Map.keys
			|> Enum.reduce(mutation, fn path, collect ->
				collect
				|> Mutation.merge(["path:watch:offline", path, user], 1)
			end)
		mutation =
			Map.get(atom, :delete, %{})
			|> Map.keys
			|> Enum.reduce(mutation, fn path, collect ->
				collect
				|> Mutation.delete(["path:watch:offline", path, user])
			end)

		{:ok, mutation}
	end

end
