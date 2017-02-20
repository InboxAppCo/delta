defmodule Delta.Queue do
	alias Delta.Mutation
	alias Delta.UUID
	alias Delta.Query

	@day 86400000

	def write(store, mutation, key) do
		mutation
		|> Mutation.atoms
		|> Task.async_stream(&write_atom(store, &1, mutation, key), max_concurrency: 100)
		|> Stream.map(fn {:ok, mutation} -> mutation end)
		|> Enum.reduce(Mutation.new, fn item, collect -> Mutation.combine(collect, item) end)
	end

	def write_atom(store, atom = {path, _body}, mutation, key) do
		json = atom |> Mutation.inflate |> Poison.encode!
		shard = :os.system_time(:millisecond) |> to_day
		joined = Enum.join(path, "/")
		store
		|> Query.path(["path:watch:offline", joined])
		|> Map.keys
		|> Enum.reduce(mutation, fn user, collect ->
			collect
			|> Mutation.merge(["user:queue", "#{user}:#{shard}", key], json)
		end)
	end

	def sync(store, user, uuid) do
		uuid
		|> since
		|> Task.async_stream(fn shard ->
			store
			|> Query.path(["user:queue", "#{user}:#{shard}"], %{min: uuid})
			|> Stream.map(fn {key, value} -> {key, Poison.decode!(value)} end)
		end, max_concurrency: 10, timeout: 30_000)
		|> Stream.flat_map(fn {:ok, values} -> values end)
		|> Enum.sort_by(fn {key, _value} -> key end)
	end

	def since(uuid) do
		(:os.system_time(:millisecond) |> to_day)
		|> Stream.iterate(fn next ->
			cond do
				UUID.ascending_from(next) <= uuid -> :stop
				true -> next - @day
			end
		end)
		|> Stream.take_while(&(&1 !== :stop))
		|> Enum.reverse
	end

	def to_day(time) do
		time = time |> round
		Integer.floor_div(time, @day) * @day
	end
end
