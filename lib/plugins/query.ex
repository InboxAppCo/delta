defmodule Delta.Plugin.Query do
	defmacro __using__(_opts) do
		use Delta.Base
		alias Delta.Query

		quote do
			def query_path(path, opts \\ %{}) do
				query_path("delta-master", path, opts)
			end

			def query_path(user, path, opts \\ %{}) do
				case interceptors
					|> Stream.map(&(&1.resolve_query(path, user, opts)))
					|> Stream.filter(&(&1 !== nil))
					|> Stream.take(1)
					|> Enum.to_list
				do
					[result] -> result
					[] ->
						Query.path(read, path, opts)
				end
				Query.path(read, path, opts)
			end

			def query(input) do
				Query.execute(input, read)
			end
		end
	end
end
