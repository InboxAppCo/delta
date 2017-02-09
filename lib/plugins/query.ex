defmodule Delta.Plugin.Query do
	defmacro __using__(_opts) do
		alias Delta.Query
		alias Delta.Dynamic
		alias Delta.Mutation

		quote do

			def query_path(path, opts \\ %{}) do
				query_path(path, "delta-master", opts)
			end

			def query_path(path, user, opts) do
				case interceptors()
					|> Stream.map(&(&1.resolve_query(path, user, opts)))
					|> Stream.filter(&(&1 !== nil))
					|> Stream.take(1)
					|> Enum.to_list
				do
					[result] -> result
					[] -> Query.path(read(), path, opts)
				end
			end

			def query(input) do
				query(input, "delta-master")
			end

			def query(input, user) do
				input
				|> Query.atoms
				|> ParallelStream.map(fn {path, opts} ->
					{path, opts, query_path(path, user, opts)}
				end)
				|> Enum.reduce(Mutation.new, fn {path, opts, data}, collect ->
					collect
					|> Dynamic.put([:merge | path], data)
					|> delete(path, opts)
				end)
			end

			defp delete(mutation, path, opts) do
				case Map.take(opts, [:min, :max]) do
					%{} -> mutation
					_ ->
						mutation
						|> Dynamic.put([:delete | path], 1)
				end
			end

			def handle_command("delta.query", body, data) do
				%{merge: merge, delete: delete} = query(body, data.user)
				{:reply, %{
					"$merge": merge,
					"$delete": delete,
				}, data}
			end
		end
	end
end
