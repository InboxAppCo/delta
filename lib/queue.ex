defmodule Delta.Queue do
	alias Delta.Mutation
	alias Delta.UUID

	@day 86400000

	def write(mutation) do
		mutation
		|> Mutation.atoms
		|> Task.async_stream(&write_atom(&1, mutation), max_concurrency: 100)
		|> Stream.map(fn {:ok, mutation} -> mutation end)
		|> Enum.reduce(Mutation.new, fn item, collect -> Mutation.combine(collect, item) end)
	end

	def write_atom(atom = {path, _body}, mutation) do
		json = atom |> Mutation.inflate |> Poison.encode!
		key = UUID.ascending
		shard = :os.system_time(:millisecond) |> to_day
		joined = Enum.join(path, "/")
		["path:watch:offline", joined]
		|> Delta.query_path
		|> Map.keys
		|> Enum.reduce(mutation, fn user, collect ->
			collect
			|> Mutation.merge(["user:queue", "#{user}:#{shard}", key], json)
		end)
	end

	def sync(user, uuid) do
		uuid
		|> since
		|> Task.async_stream(fn shard ->
			["user:queue", "#{user}:#{shard}"]
			|> Delta.query_path(%{min: uuid})
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
		(time / @day |> round) * @day
	end
end
