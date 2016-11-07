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
		end
	end
end
