defmodule Delta.Dynamic do

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

	def get(input, path) do
		Kernel.get_in(input, path)
	end

	def delete(input, [h]) do
		Map.delete(input, h)
	end

	def delete(input, [h | t]) do
		child =
			case Map.get(input, h) do
				match = %{} -> match
				_ -> %{}
			end
		Map.put(input, h, delete(child, t))
	end

	def combine(left, right) do
		Map.merge(left, right, &combine/3)
	end

	defp combine(_key, left = %{}, right = %{}) do
		combine(left, right)
	end

	defp combine(_key, _left, right) do
		right
	end

	def flatten(input, path \\ []) do
		input
		|> Enum.flat_map(fn {key, value} ->
			full = [key | path]
			case is_map(value) do
				true -> flatten(value, full)
				_ -> [{full, value}]
			end
		end)
	end

	def atoms(input, path \\ []) do
		case is_map(input) do
			false -> []
			true ->
				[
					{path, input} |
					Enum.flat_map(input, fn {key, value} ->
						atoms(value, [key | path])
					end)
				]
		end
	end

end
