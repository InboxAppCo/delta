defmodule Delta.Plugin.Watch do
	defmacro __using__(_opts) do
		alias Delta.Watch

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
		end
	end
end

defmodule Delta.Interceptor.Watch do
	use Delta.Interceptor

	def intercept_write([root, _, _], _user, _atom, _mut) when root == "user:watch:online" or root == "user:watch:offline" do
		:ok
	end
end
