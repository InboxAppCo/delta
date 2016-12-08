defmodule Delta.Stores.Postgres do
	def init(postgres) do
		%{
			postgres: postgres,
			insert: [],
			delete: []
		}
	end

	def merge(state, path, value) do
		json = Poison.encode!(value)
		%{
			state |
			insert: [{Enum.join(path, "."), json} | state.insert]
		}
	end

	def delete(state, _path) do
		state
	end

	def query_path(state, path, opts) do
		{min, max} = Delta.Store.range(path, opts)
		Postgrex.query!(state.postgres, "SELECT path, value FROM data WHERE path >= $1 AND path < $2", [min, max])
		|> Map.get(:rows)
		|> Stream.map(fn [path, value] -> {String.split(path, "."), value} end)
		|> Delta.Store.inflate(path, opts)
	end

	def execute(state) do
		{_, statement, params} =
			state.insert
			|> Enum.reduce({1, "", []}, fn {path, json}, {index, statement, params} ->
				{
					index + 2,
					statement <> "($#{index}, $#{index + 1})",
					[path, json | params],
				}
		end)
		state.postgres
		|> Postgrex.query!("INSERT INTO data(path, value) VALUES #{statement} ON CONFLICT (path) DO UPDATE SET value = excluded.value", params)
	end

end
