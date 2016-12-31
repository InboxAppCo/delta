defmodule Delta.Plugin.Watch do
	defmacro __using__(_opts) do
		alias Delta.Watch

		quote do
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
		end
	end
end
