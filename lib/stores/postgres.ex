defmodule Delta.Stores.Postgres do
	def init(pid) do
		pid
	end

	def merge(state, []) do

	end

	def merge(state, atoms) do
		{_, statement, params} =
			atoms
			|> Enum.reduce({1, "", []}, fn {path, value}, {index, statement, params} ->
				{
					index + 2,
					statement <> "($#{index}, $#{index + 1})",
					[Enum.join(path, "."), Poison.encode!(value) | params],
				}
		end)
		state
		|> Postgrex.query!("INSERT INTO data(path, value) VALUES #{statement} ON CONFLICT (path) DO UPDATE SET value = excluded.value", params)
	end

	def delete(state, []) do

	end

	def delete(state, atoms) do
		{_, statement, params} =
			atoms
			|> Enum.reduce({1, [], []}, fn {path, _}, {index, statement, params} ->
				{min, max} = Delta.Store.range(path, %{min: nil, max: nil})
				{
					index + 2,
					["(path >= #{index} AND path < #{index + 1})" | statement],
					[min, max | params],
				}
			end)
		state
		|> Postgrex.query!("DELETE FROM data WHERE #{Enum.join(statement, " OR ")}", params)
	end

	def query_path(state, path, opts) do
		{min, max} = Delta.Store.range(path, opts)
		state
		|> Postgrex.query!("SELECT path, value FROM data WHERE path >= $1 AND path < $2", [min, max])
		|> Map.get(:rows)
		|> Stream.map(fn [path, value] -> {String.split(path, "."), value} end)
		|> Delta.Store.inflate(path, opts)
	end

	def execute(state) do
	end

end
