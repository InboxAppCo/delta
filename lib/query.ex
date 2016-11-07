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
		|> Enum.filter(&atom?(&1))
		|> Enum.map(fn {path, opts} -> {Enum.reverse(path), opts} end)
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
		args
		|> store.init
		|> store.query_path(path, opts)
		|> Kernel.get_in(path) || %{}
	end

end
