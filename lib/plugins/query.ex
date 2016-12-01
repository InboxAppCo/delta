defmodule Delta.Plugin.Query do
	defmacro __using__(_opts) do
		alias Delta.Query
		alias Delta.Dynamic

		quote do
			use Delta.Base

			def query_path(path, opts \\ %{}) do
				query_path("delta-master", path, opts)
			end

			def query_path(user, path, opts) do
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
			end

			def query(input) do
				query("delta-master", input)
			end

			def query(user, input) do
				input
				|> Query.atoms
				|> ParallelStream.map(fn {path, opts} ->
					{path, query_path(user, path, opts)}
				end)
				|> Enum.reduce(%{}, fn {path, data}, collect ->
					collect
					|> Dynamic.put([:merge | path], data)
					|> Dynamic.put([:delete | path], 1)
				end)
			end
		end
	end
end
