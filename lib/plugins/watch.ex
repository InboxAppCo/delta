defmodule Delta.Plugin.Watch do
	defmacro __using__(_opts) do
		alias Delta.Watch
		alias Delta.Dynamic

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

			def handle_info({:mutation, mutation = %{merge: merge, delete: delete}}, data) do
				{"delta.mutation", %{
					"$merge": merge,
					"$delete": delete,
				}, data}
			end

			def handle_command("delta.subscribe", body, state = %{user: user}) do
				["user:watch:online", user]
				|> query_path
				|> Map.keys
				|> Stream.map(&String.split(&1, "/"))
				|> Enum.each(&watch/1)
				{:reply, true, state}
			end

			def handle_command("delta.watch", body, state) do
				body
				|> Dynamic.flatten
				|> Enum.each(fn {path, _} -> watch(path) end)
				{:reply, true, state}
			end

			def handle_command("delta.unwatch", body, state) do
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
