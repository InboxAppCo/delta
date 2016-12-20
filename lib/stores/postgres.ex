defmodule Delta.Stores.Postgres do
	def init(pid) do
		pid
	end

	def merge(state, []) do

	end

	def merge(state, atoms) do
		{_, statement, params} =
			atoms
			|> Enum.reduce({1, [], []}, fn {path, value}, {index, statement, params} ->
				{
					index + 2,
					["($#{index}, $#{index + 1})" | statement],
					[Enum.join(path, "|"), Poison.encode!(value) | params],
				}
		end)
		state
		|> Postgrex.query!("INSERT INTO data(path, value) VALUES #{Enum.join(statement, ', ')} ON CONFLICT (path) DO UPDATE SET value = excluded.value" |> IO.inspect, params)
	end

	def delete(state, []) do

	end

	def delete(state, atoms) do
		atoms
		|> ParallelStream.each(fn {path, _} ->
			{min, max} = Delta.Store.range(path, %{min: nil, max: nil})
			state
			|> Postgrex.query!("DELETE FROM data WHERE path >= $1 AND path < $2", [min, max])
		end)
		|> Stream.run
	end

	def query_path(state, path, opts) do
		{min, max} = Delta.Store.range(path, opts)
		state
		|> Postgrex.query!("SELECT path, value FROM data WHERE path >= $1 AND path < $2", [min, max])
		|> Map.get(:rows)
		|> Stream.map(fn [path, value] -> {String.split(path, "|"), value} end)
		|> Delta.Store.inflate(path, opts)
	end

	def execute(state) do
	end

end
