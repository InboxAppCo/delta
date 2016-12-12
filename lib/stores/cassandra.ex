defmodule Delta.Stores.Cassandra do
	# @behaviour Delta.Store
	alias CQEx.Query
	alias CQEx.Client

	def init(_) do
		{}
	end

	def merge(_state, atoms) do
		atoms
		|> Enum.map(fn {[first | [second | rest]], value} ->
			shard = shard(first, second)
			field = Enum.join(rest, ".")
			json = Poison.encode!(value)
			Query.new
			|> Query.statement(~s(
				UPDATE data.kv SET
					value = ?
				WHERE
					shard = ? AND
					field = ?))
			|> Query.put(:value, json)
			|> Query.put(:shard, shard)
			|> Query.put(:field, field)
		end)
		|> ParallelStream.each(fn query ->
			Client.new! |> Query.call!(query)
		end)
		|> Stream.run
		IO.inspect("done")
	end

	def delete(_state, atoms) do
		atoms
		|> Enum.map(fn {path, _} ->
			{shard, min, max} = range(path, %{})
			Query.new
			|> Query.statement(~s(
				DELETE FROM data.kv
				WHERE
					shard = ? AND
					field >= :min AND
					field < :max
			))
			|> Query.put(:shard, shard)
			|> Query.put(:min, min)
			|> Query.put(:max, max)
		end)
		|> ParallelStream.each(fn query ->
			Client.new! |> Query.call!(query)
		end)
		|> Stream.run
	end

	def query_path(_state, path, opts) do
		{shard, min, max} = range(path, opts)
		query =
			Query.new
			|> Query.statement(~s(
				SELECT field, value FROM data.kv
				WHERE
					shard = ? AND
					field >= :min AND
					field < :max
			))
			|> Query.put(:shard, shard)
			|> Query.put(:min, min)
			|> Query.put(:max, max)
		Client.new!
		|> Query.call!(query)
		|> Stream.map(fn [field: field, value: value] -> {String.split(shard, ".") ++ String.split(field, "."), value} end)
		|> Delta.Store.inflate(path, opts)
	end

	defp range([first | [second | rest]], opts) do
		shard = shard(first, second)
		{min, max} = Delta.Store.range(rest, opts)
		{shard, min, max}
	end


	defp shard(first, second) do
		"#{first}.#{second}"
	end

	def prefix("") do
		"ÿ"
	end

	def prefix(input) do
		index =
			input
			|> String.reverse
			|> String.to_charlist
			|> scan
		input
		|> String.to_charlist
		|> List.update_at(index, &(&1 + 1))
	end

	defp scan(input) do
		scan(input, Enum.count(input) - 1)
	end

	defp scan([head | tail], index) do
		cond do
			head < 255 -> index
			true -> scan(tail, index - 1)
		end
	end
end
