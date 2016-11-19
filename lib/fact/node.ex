defmodule Delta.Fact.Node do
	use GenServer
	alias Delta.Dynamic
	alias Delta.Watch
	alias Delta.Query

	def start_link(read, key, pred) do
		GenServer.start_link(__MODULE__, [read, key, pred], name: tuple(key, pred))
	end

	def init([read, key, pred]) do

		{:ok, %{
			key: key,
			data:
				Map.new
				|> watch(read, ["spo:#{key}", pred])
				|> watch(read, ["ops:#{key}", pred])
		}}
	end

	defp watch(data, read, path) do
		Watch.watch(path)
		data
		|> Dynamic.put(path, Query.path(read, path))
	end

	def get(read, key, pred) do
		case whereis(key, pred) do
			:undefined ->
				{:ok, pid} = __MODULE__.start_link(read, key, pred)
				pid
			pid -> pid
		end
	end

	def handle_call({:query_path, path}, _from, state = %{data: data}) do
		{:reply, Dynamic.get(data, path) || %{}, state}
	end

	def handle_info({:mutation, mutation}, state = %{data: data}) do
		{:noreply, %{
			state |
			data: Mutation.apply(data, mutation)
		}}
	end

	def name(key, pred) do
		{__MODULE__, key}
	end

	def tuple(key, pred) do
		{:via, :syn, name(key, pred)}
	end

	def whereis(key, pred) do
		name(key, pred)
		|> :syn.find_by_key
	end

	def subjects(read, o, p) do
		get(read, o, p)
		|> GenServer.call({:query_path, ["ops:#{o}", p]})
	end

	def objects(read, s, p) do
		get(read, s, p)
		|> GenServer.call({:query_path, ["spo:#{s}", p]})
	end

	def has_subject(read, o, p, s) do
		get(read, o, p)
		|> GenServer.call({:query_path, ["ops:#{o}", p, s]})
		|> is_integer
	end

	def has_object(read, s, p, o) do
		get(read, s, p)
		|> GenServer.call({:query_path, ["spo:#{s}", p, o]})
		|> is_integer
	end

end

defmodule Delta.Fact.Supervisor do
	use Supervisor
end
