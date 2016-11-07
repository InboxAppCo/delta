defmodule Delta.Mutation do
	alias Delta.Dynamic
	alias Delta.Watch

	def new(merge \\ %{}, delete \\ %{}) do
		%{
			merge: merge,
			delete: delete,
		}
	end

	def merge(input, path, value) do
		Dynamic.put(input, [:merge | path], value)
	end

	def delete(input, path) do
		Dynamic.put(input, [:delete | path], 1)
	end

	def atoms(%{merge: merge, delete: delete}) do
		Dynamic.combine(
			atoms(merge, :merge),
			atoms(delete, :delete)
		)
	end

	defp atoms(input, type) do
		input
		|> Dynamic.atoms
		|> Enum.reduce(%{}, fn {path, value}, collect ->
			Dynamic.put(collect, [Enum.reverse(path), type], value)
		end)
	end

	def combine(left, right) do
		Dynamic.combine(
			left,
			right
		)
	end

	def inflate({path, body}) do
		new
		|> Dynamic.put([:merge | path], Map.get(body, :merge) || %{})
		|> Dynamic.put([:merge | path], Map.get(body, :merge) || %{})
	end

	defp inflate(input, path, nil) do
		input
	end

	defp inflate(input, path, value) do
		Dynamic.put(input, path, value)
	end

	def prepare(mutation, interceptors, function, user) do
		mutation
		|> atoms
		|> Enum.reduce(mutation, &prepare(&2, interceptors, function, user, &1))
	end

	defp prepare(mutation, interceptors, function, user, {path, atom}) do
		Enum.reduce(interceptors, mutation, fn interceptor, collect ->
			case apply(interceptor, function, [path, user, atom, collect]) do
				{:prepare, result, next} ->
					next
					|> prepare(interceptors, function, user)
					|> combine(result)
				:ok -> collect
				result = %{merge: merge, delete: delete} -> result
			end
		end)
	end

	def apply(input, mutation) do
		deleted =
			mutation.delete
			|> Dynamic.flatten
			|> Enum.reduce(input, fn {path, value}, collect ->
				Dynamic.delete(collect, Enum.reverse(path))
			end)
		mutation.merge
		|> Dynamic.flatten
		|> Enum.reduce(deleted, fn {path, value}, collect ->
			Dynamic.put(collect, Enum.reverse(path), value)
		end)
	end


end
