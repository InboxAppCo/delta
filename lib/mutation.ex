defmodule Delta.Mutation do
	alias Delta.Dynamic

	def new(merge \\ %{}, delete \\ %{}) do
		%{
			merge: merge || %{},
			delete: delete || %{},
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
		|> Stream.map(fn {path, value} ->
			merge = Map.get(value, :merge, %{})
			delete = Map.get(value, :delete, %{})
			{path, %{
				merge: merge,
				delete: delete,
			}}
		end)
		|> Enum.into(%{})
	end

	defp atoms(input, type) do
		input
		|> Dynamic.atoms
		|> Enum.reduce(%{}, fn {path, value}, collect ->
			Dynamic.put(collect, [path, type], value)
		end)
	end

	def combine(left, right) do
		%{
			merge:
				left.merge
				|> Delta.Mutation.apply(%{delete: right.delete, merge: %{}})
				|> Delta.Mutation.apply(%{delete: %{}, merge: right.merge}),
			delete: Dynamic.combine(
				left.delete,
				right.delete
			),
		}
	end

	def combine_stream(stream, input) do
		stream
		|> Enum.reduce(input, fn item, collect -> combine(collect, item) end)
	end

	def inflate({path, body}) do
		mutation = new()
		mutation =
			cond do
				body.merge == %{} -> mutation
				true ->
					mutation
					|> Dynamic.put([:merge | path], body.merge)
			end
		mutation =
			cond do
				body.delete == %{} -> mutation
				true ->
					mutation
					|> Dynamic.put([:delete | path], body.delete)
			end
		mutation
	end

	def commit(mutation, interceptors, user) do
		mutation
		|> atoms
		|> Stream.flat_map(&commit(mutation, interceptors, user, &1))
		|> Stream.filter(&(&1 !== :ok))
		|> Enum.at(0)
	end

	def commit(mutation, interceptors, user, {path, atom}) do
		interceptors
		|> Stream.map(&apply(&1, :intercept_commit, [path, user, atom, mutation]))
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
				{:ok, result = %{merge: _merge, delete: _delete} } -> result
			end
		end)
	end

	def deliver(mutation, interceptors, user) do
		mutation
		|> trigger_interceptors(interceptors, :intercept_delivery, user)
	end

	defp trigger_interceptors(mutation, interceptors, function, user) do
		mutation
		|> atoms
		|> Stream.flat_map(&trigger_interceptors(mutation, interceptors, function, user, &1))
		|> Stream.filter(&(&1 !== :ok))
		|> Enum.at(0)
	end

	defp trigger_interceptors(mutation, interceptors, function, user, {path, atom}) do
		interceptors
		|> Stream.map(&apply(&1, function, [path, user, atom, mutation]))
	end

	def validate(mutation, interceptors, user) do
		mutation
		|> atoms
		|> Stream.flat_map(&validate(mutation, interceptors, user, &1))
		|> Stream.filter(&(&1 !== :ok))
		|> Enum.at(0)
	end

	defp validate(mutation, interceptors, user, {path, atom}) do
		interceptors
		|> Stream.map(&apply(&1, :validate_write, [path, user, atom, mutation]))
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

	def from_json(data) do
		%{
			"$merge" => merge,
			"$delete" => delete,
		} = Poison.decode!(data)
		new(merge, delete)
	end

	def to_json(%{merge: merge, delete: delete}) do
		%{
			"$merge" => merge,
			"$delete" => delete,
		}
		|> Poison.encode!
	end

	def write(mutation, {store, args}) do
		args
		|> store.init
		|> store.delete(Dynamic.flatten(mutation.delete))

		args
		|> store.init
		|> store.merge(Dynamic.flatten(mutation.merge))
	end

end
