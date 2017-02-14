defmodule Delta.Query do
	alias Delta.Dynamic

	def new() do
		%{}
	end

	def get(input, path, opts \\ []) do
		map = Enum.into(opts, %{})
		Dynamic.put(input, path, map)
	end

	def atoms(query) do
		query
		|> Dynamic.atoms
		|> Stream.filter(&atom?(&1))
		|> Stream.map(fn {key, value} -> {key, convert(value)} end)
		|> Enum.map(fn {path, opts} -> {path, opts} end)
	end

	defp atom?({_, opts}) do
		opts
		|> Map.values
		|> Enum.all?(&(!is_map(&1)))
	end

	defp convert(value) do
		%{
			min: Map.get(value, "$min") || Map.get(value, "min"),
			max: Map.get(value, "$max") || Map.get(value, "max"),
			limit: Map.get(value, "$limit") || Map.get(value, "limit", 0),
		}
	end

	def path({store, args}, path, opts \\ %{}) do
		opts = %{
			min: nil,
			max: nil,
			limit: 0
		} |> Map.merge(opts)
		case args
			|> store.init
			|> store.query_path(path, opts)
			|> Kernel.get_in(path) do
			nil -> %{}
			result -> result
		end
	end
end
