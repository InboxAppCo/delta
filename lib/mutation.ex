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

	def layers(%{merge: merge, delete: delete}) do
		Dynamic.combine(
			layers(merge, :merge),
			layers(delete, :delete)
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

	defp layers(input, type) do
		input
		|> Dynamic.layers
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

	def write(mutation, stores) do
		merges = Dynamic.flatten(mutation.merge)
		deletes = Dynamic.flatten(mutation.delete)
		stores
		|> Task.async_stream(&write(&1, merges, deletes))
		|> Stream.run
	end

	defp write({store, args}, merges, deletes) do
		args
		|> store.init
		|> store.delete(deletes)

		args
		|> store.init
		|> store.merge(merges)
	end

end
