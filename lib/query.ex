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
		|> Stream.map(fn {key, value} -> {key, Dynamic.keys_to_atoms(value)} end)
		|> Stream.filter(&atom?(&1))
		|> Enum.map(fn {path, opts} -> {path, opts} end)
	end

	defp atom?({_, opts}) do
		opts
		|> Map.keys
		|> Enum.filter(fn key ->
			case key do
				:min -> false
				:max -> false
				:limit -> false
				_ -> true
			end
		end)
		|> Enum.count == 0
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
