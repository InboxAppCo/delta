defmodule Delta.Stores.Memory do
	@delimiter " "
	@table :delta_table
	def create_table do
		:ets.new(@table, [
			:ordered_set,
			:public,
			:named_table,
			read_concurrency: true,
			write_concurrency: true,
		])
	end

	def init(_) do
	end

	def merge(_state, []) do
	end

	def merge(_state, atoms) do
		atoms
		|> Enum.each(fn {path, value} ->
			joined = Enum.join(path, @delimiter)
			:ets.insert(@table, {joined, value})
		end)
	end

	def delete(_state, []) do
	end

	def delete(_state, atoms) do
		atoms
		|> Stream.flat_map(fn {path, _} ->
			{min, max} = Delta.Store.range(path, @delimiter, %{min: nil, max: nil})
			iterate_keys(min, max)
			|> Stream.each(&:ets.delete(@table, &1))
		end)
		|> Stream.run
	end

	def query_path(_state, path, opts) do
		{min, max} = Delta.Store.range(path, @delimiter, opts)

		iterate_keys(min, max)
		|> Stream.map(&:ets.lookup(@table, &1))
		|> Stream.map(&List.first/1)
		|> Stream.filter(fn item -> item !== nil end)
		|> Stream.map(fn {path, value} -> {String.split(path, @delimiter), value} end)
		|> Delta.Store.inflate(path, opts, &(&1))
	end

	defp iterate_keys(min, max) do
		min
		|> Stream.iterate(fn next ->
			cond do
				next === :"$end_of_table" -> :stop
				next >= max -> :stop
				true -> :ets.next(@table, next)
		   end
	   end)
	   |> Stream.take_while(fn next -> next !== :stop end)
	end

	def execute(_state) do
	end

end
