defmodule Delta.Stores.Azure do
	alias Delta.Dynamic
	@delimiter "×"

	def init(_) do
		nil
	end

	def merge(state, atoms) do
		atoms
		|> Stream.map(fn {key, value} ->
			[root, shard, row | path] = key
			partition = "#{root}×#{shard}"
			{{partition, row}, "_" <> Enum.join(path, @delimiter), value}
		end)
		|> Enum.reduce(%{}, fn {key, path, value}, collect ->
			Dynamic.put(collect, [key, path], value)
		end)
		|> Enum.each(fn {{partition, row}, value} ->
			Azex.Table.insert_replace("delta", partition, row, value)
		end)
	end

	def delete(state, atoms) do
	end

	def query_path(state, [root, shard, row | path]) do
	end

	def query_path(state, [root, shard]) do
	end

	def query_path(state, path, opts) do
	end


	def execute(_state) do
	end

end
