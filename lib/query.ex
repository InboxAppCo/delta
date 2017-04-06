defmodule Delta.Query do
	alias Delta.Dynamic

	def new() do
		%{}
	end

	def get(input, path, opts \\ []) do
		map = Enum.into(opts, %{})
		Dynamic.put(input, path, map)
	end

	def layers(query) do
		query
		|> Dynamic.layers
		|> Stream.filter(&layer?(&1))
		|> Stream.map(fn {key, value} -> {key, convert(value)} end)
		|> Enum.map(fn {path, opts} -> {path, opts} end)
	end

	defp layer?({_, opts}) do
		opts
		|> Map.values
		|> Enum.all?(&(!is_map(&1)))
	end

	defp convert(value) do
		value
		|> Stream.map(fn {key, value} ->
			key =
				key
				|> String.trim("$")
				|> String.to_atom
			{key, value}
		end)
		|> Enum.into(%{})
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
			|> Dynamic.get(path) do
			nil -> %{}
			result -> result
		end
	end
end
