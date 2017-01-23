defmodule Delta.Store do
	alias Delta.Dynamic

	def inflate(stream, path, opts, decoder \\ &Poison.decode!/1) do
		count = Enum.count(path)
		stream
		|> Stream.chunk_by(fn {path, _value} -> Enum.at(path, count) end)
		|> Stream.take(
			case opts.limit do
				0 -> 10000
				_ -> opts.limit
			end
		)
		|> Stream.flat_map(fn x -> x end)
		|> Enum.reduce(%{}, fn {path, value}, collect ->
			Dynamic.put(collect, path, decoder.(value))
		end)
	end

	def range(path, delimit, opts) do
		case {Map.get(opts, :min), Map.get(opts, :max)} do
			{nil, nil} ->
				min = Enum.join(path, delimit)
				max = prefix(min)
				{min, max}
			{min, nil} ->
				min = Enum.join(path ++ [min], delimit)
				max = prefix(Enum.join(path, delimit))
				{min, max}
			{nil, max} ->
				min = Enum.join(path, delimit)
				max = Enum.join(path ++ [max], delimit)
				{min, max}
			{min, max} ->
				min = Enum.join(path ++ [min], delimit)
				max = Enum.join(path ++ [max], delimit)
				{min, max}
		end
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
		|> String.Chars.to_string
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
