defmodule Delta.Mutation do
	alias Delta.Dynamic

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
			Dynamic.put(collect, [path, type], value)
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
		|> Dynamic.put([:delete | path], Map.get(body, :delete) || %{})
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
				result = %{merge: _merge, delete: _delete} -> result
			end
		end)
	end

	def apply(input, mutation) do
		deleted =
			mutation.delete
			|> Dynamic.flatten
			|> Enum.reduce(input, fn {path, _value}, collect ->
				Dynamic.delete(collect, path)
			end)
		mutation.merge
		|> Dynamic.flatten
		|> Enum.reduce(deleted, fn {path, value}, collect ->
			Dynamic.put(collect, path, value)
		end)
	end

	def write(mutation, {store, args}) do
		store.init(args)
		|> store.delete(Dynamic.flatten(mutation.delete))

		store.init(args)
		|> store.merge(Dynamic.flatten(mutation.merge))
	end

	defp write_merge(transaction, store, merge) do
		merge
		|> Dynamic.flatten
		|> Enum.reduce(transaction, fn {path, value}, collect ->
			store.merge(collect, path, value)
		end)
	end

	defp write_delete(transaction, store, delete) do
		delete
		|> Dynamic.flatten
		|> Enum.reduce(transaction, fn {path, _}, collect ->
			store.delete(collect, path)
		end)
	end


end
