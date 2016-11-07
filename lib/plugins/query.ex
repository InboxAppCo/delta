defmodule Delta.Plugin.Query do
	defmacro __using__(_opts) do

		quote do
			def query_path(path, opts \\ %{}) do
				opts = %{
					min: nil,
					max: nil,
					limit: 0
				} |> Map.merge(opts)
				{store, args} = read
				args
				|> store.init
				|> store.query_path(path, opts)
				|> Kernel.get_in(path) || %{}
			end

			def query(query) do
				query
				|> Query.atoms
				|> ParallelStream.map(fn {path, opts} ->
					{path, query_path(path, opts)}
				end)
				|> Enum.reduce(%{}, fn {path, data}, collect -> Dynamic.put(collect, path, data) end)
			end
		end
	end
end
