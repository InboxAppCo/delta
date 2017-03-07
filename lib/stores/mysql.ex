defmodule Delta.Stores.MySql do
	@delimiter " "
	def init(pid) do
		pid
	end

	def merge(_state, []) do

	end

	def schema(pid) do
		pid
		|> Mariaex.query!(~s(

		))
	end

	def merge(state, atoms) do
		{_, statement, params} =
			atoms
			|> Enum.reduce({1, [], []}, fn {path, value}, {index, statement, params} ->
				{
					index + 2,
					["(?, ?)" | statement],
					[Enum.join(path, @delimiter), Poison.encode!(value) | params],
				}
		end)
		state
		|> Mariaex.query!("INSERT INTO data(path, value) VALUES #{Enum.join(statement, ", ")} ON DUPLICATE KEY UPDATE value = value", params,  pool: DBConnection.Poolboy)
	end

	def delete(_state, []) do

	end

	def delete(state, atoms) do
		atoms
		|> ParallelStream.each(fn {path, _} ->
			{min, max} = Delta.Store.range(path, @delimiter, %{min: nil, max: nil})
			state
			|> Mariaex.query!("DELETE FROM data WHERE path >= ? AND path < ?", [min, max], pool: DBConnection.Poolboy)
		end)
		|> Stream.run
	end

	def query_path(state, path, opts) do
		{min, max} = Delta.Store.range(path, @delimiter, opts)
		{:ok, result} =
			state
			|> Mariaex.transaction(fn conn ->
				conn
				|> Mariaex.stream("SELECT path, value FROM data WHERE path >= ? AND path < ? ORDER BY path ASC", [min, max])
				|> Stream.flat_map(&Map.get(&1, :rows))
				|> Stream.map(fn [path, value] -> {String.split(path, @delimiter), value} end)
				|> Delta.Store.inflate(path, opts)
			end, pool: DBConnection.Poolboy)
		result
	end

	def execute(_state) do
	end

end
