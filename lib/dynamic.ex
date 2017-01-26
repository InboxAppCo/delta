defmodule Delta.Dynamic do

	def default(input, default), do: default(input, nil, default)
	def default(input, compare, default) when input == compare, do: default
	def default(input, compare, default), do: input

	@doc ~S"""
	Inserts or updates value at `path`

	## Examples
		iex> Dynamic.put(%{}, [:a, :b], 1)
		%{a: %{b: 1}}
		iex> Dynamic.put(%{}, [:a], 1)
		%{a: 1}
	"""
	def put(input, [h], value) do
		Map.put(input, h, value)
	end

	def put(input, [h | t], value) do
		child =
			case Map.get(input, h) do
				match = %{} -> match
				_ -> %{}
			end
		Map.put(input, h, put(child, t, value))
	end

	@doc ~S"""
	Gets value at path

	## Examples
		iex> Dynamic.get(%{a: %{b: 1}}, [:a, :b])
		1
	"""
	def get(input, []) do
		input
	end

	def get(input, path) do
		Kernel.get_in(input, path)
	end

	@doc ~S"""
	Deletes value at path

	## Examples
		iex> Dynamic.delete(%{a: %{b: 1}}, [:a, :b])
		%{a: %{}}
	"""
	def delete(input, [h]) do
		Map.delete(input, h)
	end

	def delete(input, [h | t]) do
		case Map.get(input, h) do
			child when is_map(child) ->
				Map.put(input, h, delete(child, t))
			_ -> input
		end
	end

	@doc ~S"""
	Deep merge two maps

	## Examples
		iex> Dynamic.combine(%{a: %{b: 1}}, %{a: %{c: 1}})
		%{a: %{b: 1, c: 1}}
	"""
	def combine(left, right) do
		Map.merge(left, right, &combine/3)
	end

	defp combine(_key, left = %{}, right = %{}) do
		combine(left, right)
	end

	defp combine(_key, _left, right) do
		right
	end

	@doc ~S"""
	Returns a list of paths and values

	## Examples
		iex> Dynamic.flatten(%{a: %{b: 1}})
		[{[:a, :b], 1}]
	"""
	def flatten(input, path \\ []) do
		input
		|> Enum.flat_map(fn {key, value} ->
			full = [key | path]
			cond do
				value == %{} -> []
				is_map(value) ->
					flatten(value, full)
				true -> [{Enum.reverse(full), value}]
			end
		end)
	end

	@doc ~S"""
	Return layers of a map

	## Examples
		iex> Dynamic.atoms(%{a: %{b: 1}})
		[
			{[], %{a: %{b: 1}}},
			{[:a], %{b: 1}},
		]
	"""
	def atoms(input, path \\ []) do
		case is_map(input) do
			false -> []
			true ->
				[
					{Enum.reverse(path), input} |
					Enum.flat_map(input, fn {key, value} ->
						atoms(value, [key | path])
					end)
				]
		end
	end

	def keys_to_atoms(input) do
		for {key, val} <- input, into: %{}, do: {String.to_atom(key), val}
	end

	def keys_to_string(input) do
		for {key, val} <- input, into: %{}, do: {Atom.to_string(key), val}
	end

end
