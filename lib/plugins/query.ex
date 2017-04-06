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
					|> Enum.at(0)
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
				cond do
					opts === %{} ->
						mutation
						|> Dynamic.put([:delete | path], 1)
					true -> mutation
				end
			end

			def handle_command({"delta.query", body, _version}, state = %{ user: user }) do
				%{merge: merge, delete: delete} = query(body, user)
				{:reply, %{
					"$merge": merge,
					"$delete": delete,
				}, state}
			end
		end
	end
end
