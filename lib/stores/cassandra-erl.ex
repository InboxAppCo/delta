# defmodule Delta.Stores.Cassandra.Erl do
# 	# @behaviour Delta.Store
# 	alias Delta.Mutation
#
# 	def init(_) do
# 		{}
# 	end
#
# 	def merge(_state, atoms) do
# 		atoms
# 		|> ParallelStream.each(fn {[first | [second | rest]], value} ->
# 			shard = shard(first, second)
# 			field = Enum.join(rest, ".")
# 			json = Poison.encode!(value)
# 			~s(
# 				UPDATE data.kv SET
# 					value = ?
# 				WHERE
# 					shard = ? AND
# 					field = ?
# 			)
# 			|> :erlcass.execute([
# 				{:text, json},
# 				{:text, shard},
# 				{:text, field},
# 			])
# 		end)
# 		|> Stream.run
# 	end
#
# 	def delete(_state, atoms) do
# 		atoms
# 		|> ParallelStream.each(fn {path, _} ->
# 			{shard, min, max} = range(path, %{})
# 			~s(
# 				DELETE FROM data.kv
# 				WHERE
# 					shard = ? AND
# 					field >= :min AND
# 					field < :max
# 			)
# 			|> :erlcass.execute([
# 				{:text, shard},
# 				{:text, min},
# 				{:text, max},
# 			])
# 		end)
# 		|> Stream.run
# 	end
#
# 	def query_path(_state, path, opts) do
# 		{shard, min, max} = range(path, opts)
# 		{:ok, results} =
# 			~s(
# 				SELECT field, value FROM data.kv
# 				WHERE
# 					shard = ? AND
# 					field >= :min AND
# 					field < :max
# 			)
# 			|> :erlcass.execute([
# 				{:text, shard},
# 				{:text, min},
# 				{:text, max},
# 			])
# 		results
# 		|> Stream.map(fn {field, value} -> {String.split(shard, ".") ++ String.split(field, "."), value} end)
# 		|> Delta.Store.inflate(path, opts)
# 	end
#
# 	def sync(_state, user, offset) do
# 		{offset, []}
# 		|> Stream.iterate(fn {current, _} ->
# 			case current do
# 				nil -> :stop
# 				_ ->
# 					{:ok, results} =
# 						~s(
# 							SELECT key, value
# 							FROM data.queue
# 							WHERE
# 								user = ? AND
# 								key > ?
# 							LIMIT 1000
# 						)
# 						|> :erlcass.execute([
# 							{:text, user},
# 							{:text, current}
# 						])
# 					{next, _} = List.last(results) || {nil, nil}
# 					{next, results}
# 			end
# 		end)
# 		|> Stream.take_while(&(&1 !== :stop ))
# 		|> Stream.flat_map(fn {_, value} -> value end)
# 		|> Stream.map(fn {_, value} -> value end)
# 		|> Stream.map(&Mutation.from_json/1)
# 	end
#
# 	defp range([first | [second | rest]], opts) do
# 		shard = shard(first, second)
# 		{min, max} = Delta.Store.range(rest, ".", opts)
# 		{shard, min, max}
# 	end
#
#
# 	defp shard(first, second) do
# 		"#{first}.#{second}"
# 	end
#
# 	def prefix("") do
# 		"ÿ"
# 	end
#
# 	def prefix(input) do
# 		index =
# 			input
# 			|> String.reverse
# 			|> String.to_charlist
# 			|> scan
# 		input
# 		|> String.to_charlist
# 		|> List.update_at(index, &(&1 + 1))
# 	end
#
# 	defp scan(input) do
# 		scan(input, Enum.count(input) - 1)
# 	end
#
# 	defp scan([head | tail], index) do
# 		cond do
# 			head < 255 -> index
# 			true -> scan(tail, index - 1)
# 		end
# 	end
# end
