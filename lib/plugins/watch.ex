defmodule Delta.Plugin.Watch do
	defmacro __using__(_opts) do
		alias Delta.Watch
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

			def handle_info({:mutation, %{merge: merge, delete: delete}}, data) do
				{"delta.mutation", %{
					"$merge": merge,
					"$delete": delete,
				}, data}
			end

			def handle_command("delta.subscribe", body, state = %{user: user}) do
				["user:watch:online", user]
				|> Delta.query_path
				|> Map.keys
				|> Stream.map(&String.split("/"))
				|> Enum.each(&watch)
				{:reply, true, state}
			end
		end
	end
end

defmodule Delta.Interceptor.Watch do
	def intercept_write([root, user, path], _user, _atom, _mut) when root == "user:watch:online" or root == "user:watch:offline" do
		:ok
	end
end
