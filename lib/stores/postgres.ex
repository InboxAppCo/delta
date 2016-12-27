defmodule Delta.Stores.Postgres do
	@delimiter " "
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
					[Enum.join(path, @delimiter), Poison.encode!(value) | params],
				}
		end)
		state
		|> Postgrex.query!("INSERT INTO data(path, value) VALUES #{Enum.join(statement, ", ")} ON CONFLICT (path) DO UPDATE SET value = excluded.value", params)
	end

	def delete(state, []) do

	end

	def delete(state, atoms) do
		atoms
		|> ParallelStream.each(fn {path, _} ->
			{min, max} = Delta.Store.range(path, @delimiter, %{min: nil, max: nil})
			state
			|> Postgrex.query!("DELETE FROM data WHERE path >= $1 AND path < $2", [min, max])
		end)
		|> Stream.run
	end

	def query_path(state, path, opts) do
		{min, max} = Delta.Store.range(path, @delimiter, opts)
		{:ok, result} =
			state
			|> Postgrex.transaction(fn conn ->
				conn
				|> Postgrex.stream("SELECT path, value FROM data WHERE path >= $1 AND path < $2 ORDER BY path ASC", [min, max])
				|> Stream.flat_map(&Map.get(&1, :rows))
				|> Stream.map(fn [path, value] -> {String.split(path, @delimiter), value} end)
				|> Delta.Store.inflate(path, opts)
			end, pool: DBConnection.Poolboy)
		result
	end

	def execute(state) do
	end

end
