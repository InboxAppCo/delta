defmodule Delta.Plugin.Query do
	defmacro __using__(_opts) do
		alias Delta.Query

		quote do
			def query_path(path, opts \\ %{}) do
				Query.path(read, path, opts)
			end

			def query(input) do
				Query.execute(input, read)
			end
		end
	end
end
