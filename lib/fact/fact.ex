defmodule Delta.Fact do
	require Logger
	alias Delta.Mutation
	alias Delta.Query


	defp encode(input) when is_binary(input) do
		input
		|> String.replace(".", "|")
	end

	defp encode(input), do: input

	defp decode(input) when is_binary(input) do
		input
		|> String.replace("|", ".")
	end

	defp decode(input), do: input

	def add(s, p, o) do
		add(s, p, o, :os.system_time(:milli_seconds))
	end

	def add(s, p, o, t) do
		Logger.info("Adding fact #{s}-#{p}-#{o}")
		s = encode(s)
		p = encode(p)
		o = encode(o)

		Mutation.new
		|> Mutation.merge(["spo:#{s}", p, o], t)
		|> Mutation.merge(["ops:#{o}", p, s], t)
	end

	def query(read, [returns | steps]) do
		{lexed, _} =
			steps
			|> Enum.map_reduce(MapSet.new, &lex/2)
		results =
			lexed
			|> Enum.reduce(%{}, fn step, collect -> execute(read, step, collect) end)
		[target | rest] = Enum.reverse(returns)
		parents(results, target)
		|> Enum.flat_map(fn {{_, params}, values} ->
			Enum.map(values, fn value ->
				Enum.reverse([value | Enum.map(rest, &Map.get(params, &1))])
			end)
		end)
	end

	def lex(input, vars) do
		input
		|> Enum.map_reduce(vars, fn item, vars ->
			cond do
				is_binary(item) ->
					{{:string, item}, vars}
				is_atom(item) && MapSet.member?(vars, item) ->
					{{:var_ref, item}, vars}
				is_atom(item) ->
					{{:var_dec, item}, MapSet.put(vars, item)}
			end
		end)
	end

	defp parents(collect, type) do
		collect
		|> Enum.filter(fn {{head, _}, _} -> head == type end)
	end

	defp execute(read, step, collect) do
		case step do
			# Find objects
			[string: s, string: p, var_dec: o] ->
				Map.put(collect, {o, %{}}, sp_o(read, s, p))

			# Find subjects
			[var_dec: s, string: p, string: o] ->
				Map.put(collect, {s, %{}}, op_s(read, o, p))

			[var_ref: s, string: p, var_dec: o] ->
				result =
					parents(collect, s)
					|> Enum.flat_map(fn {{key, params}, value} ->
						Enum.map(value, fn x ->
							{{o, Map.put(params, key, x)}, sp_o(read, x, p)}
						end)
					end)
					|> Enum.into(%{})
				Map.merge(collect, result)

			[var_dec: s, string: p, var_ref: o] ->
				result =
					parents(collect, o)
					|> Enum.flat_map(fn {{key, params}, value} ->
						Enum.map(value, fn x ->
							{{s, Map.put(params, key, x)}, op_s(read, x, p)}
						end)
					end)
					|> Enum.into(%{})
				Map.merge(collect, result)
			[var_ref: s, string: p, string: o] ->
				Logger.info("Filtering #{s} that have #{p} to #{o}")
			 	filtered =
					parents(collect, s)
					|> Enum.reduce(collect, fn {key, values}, collect ->
						Map.put(collect, key, Enum.filter(values, fn item -> has_o(read, item, p, o) end))
					end)
			[string: s, string: p, var_ref: o] ->
				Logger.info("Filtering #{o} that have #{p} from #{s}")
			 	filtered =
					parents(collect, s)
					|> Enum.reduce(collect, fn {key, values}, collect ->
						Map.put(collect, key, Enum.filter(values, fn item -> has_s(read, item, p, s) end))
					end)

			true -> collect
		end
	end

	defp sp_o(read, s, p) do
		Logger.info("Fetching objects where #{p} from #{s}")
		s = encode(s)
		p = encode(p)
		read
		|> Delta.Fact.Node.objects(s, p)
		|> Map.keys
		|> IO.inspect
		|> Enum.map(&decode/1)
	end

	defp op_s(read, o, p) do
		Logger.info("Fetching subjects where #{p} to #{o}")
		o = encode(o)
		p = encode(p)
		read
		|> Delta.Fact.Node.subjects(o, p)
		|> Map.keys
		|> Enum.map(&decode/1)

	end

	defp has_o(read, s, p, o) do
		Logger.info("Verifying subject #{s} #{p} to #{o}")
		s = encode(s)
		p = encode(p)
		o = encode(o)
		read
		|> Delta.Fact.Node.has_object(s, p, o)
	end

	defp has_s(read, o, p, s) do
		Logger.info("Verifying object #{o} #{p} from #{s}")
		s = encode(s)
		p = encode(p)
		o = encode(o)
		read
		|> Delta.Fact.Node.has_subject(o, p, s)
	end

end
