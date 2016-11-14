defmodule Delta.Stores.Cassandra do
	# @behaviour Delta.Store
	alias CQEx.Query
	alias CQEx.Client
	alias Delta.Dynamic

	def init(_) do
		%{
			batch: [],
		}
	end

	def merge(state = %{batch: batch}, [first | [ second | rest ] ], value) do
		shard = shard(first, second)
		field = Enum.join(rest, ".")
		json = Poison.encode!(value)
		query =
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
		%{
			state |
			batch: [query | batch]
		}
	end

	def delete(state, _path) do
		state
	end

	def execute(state = %{batch: batch}) do
		batch
		|> ParallelStream.map(fn query ->
			Client.new!
			|> Query.call!(query)
		end)
		|> Enum.to_list
		state
	end

	def query_path(_state, path, opts) do
		count = Enum.count(path)
		{shard, min, max} = args(path, opts)
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
		|> Stream.chunk_by(fn {path, _value} -> Enum.at(path, count) end)
		|> Stream.take(
			case opts.limit do
				0 -> 10000
				_ -> count
			end
		)
		|> Stream.flat_map(fn x -> x end)
		|> Enum.reduce(%{}, fn {path, value}, collect ->
			Dynamic.put(collect, path, Poison.decode!(value))
		end)
	end

	defp args([first | [ second | rest ] ], opts) do
		shard = shard(first, second)
		min =
			case opts.min do
				nil -> Enum.join(rest, ".")
				min -> Enum.join(rest ++ [min], ".")
			end
		max =
			case opts.max do
				nil -> prefix(min)
				max -> Enum.join(rest ++ [max], ".")
			end
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
