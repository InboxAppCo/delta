defmodule Delta.Server.Connection do
	use GenServer
	alias Socket.Web
	alias Delta.Server.Processor

	def start_link(delta, socket) do
		GenServer.start_link(__MODULE__, [delta, socket])
	end

	def init([delta, socket]) do
		delta.handle_connect(socket)
		conn = self()
		Task.start_link(fn -> read(socket, conn) end)
		{:ok, %{
			socket: socket,
			delta: delta,
			data: %{}
		}}
	end

	def handle_cast({:process, json}, state) do
		cmd = json |> Poison.decode!
		key = Map.get(cmd, "key")
		version = Map.get(cmd, "version", 0)
		body = Map.get(cmd, "body")
		action = Map.get(cmd, "action")
		{result, body, data} = process({action, body, version}, state.delta, state.data)
		write(key, result, body, version)
		{:noreply, %{
			state |
			data: data
		}}
	end

	def handle_cast({:write, key, result, body, version}, state) do
		json =
			%{
				key: key,
				action: result |> format,
				body: body,
				version: version
			}
			|> Poison.encode!
		Web.send(state.socket, {:text, json})
		{:noreply, state}
	end

	def handle_info(msg, state) do
		{:ok, data} = state.delta.handle_info(msg, state.data)
		{:noreply, %{
			state |
			data: data,
		}}
	end

	def handle_cast({:stop}, state) do
		Web.close(state.socket)
		state.delta.handle_disconnect(state.socket)
		{:stop, :normal, state}
	end

	def write(key, result, body, version \\ 0) do
		GenServer.cast(self(), {:write, key, result, body, version})
	end

	def format(action) do
		case action do
			:error -> "drs.error"
			:exception-> "drs.exception"
			:reply-> "drs.response"
			_ -> action
		end
	end

	defp process(cmd, delta, state) do
		try do
			{:ok, state} = delta.handle_precommand(cmd, state)
			{result, body, state} = delta.handle_command(cmd, state)
			{:ok, state} = delta.handle_postcommand(cmd, {result, body}, state)
			{result, body, state}
		rescue
			e -> {:exception, inspect(e), state}
		catch
			e -> {:exception, inspect(e), state}
			_, e -> {:exception, inspect(e), state}
		end
	end

	def read(socket, pid) do
		case socket |> Web.recv do
			{:ok, {type, data}} when type == :text or type == :binary ->
				GenServer.cast(pid, {:process, data})
				read(socket, pid)
			{:ok, {:ping, _}} ->
				read(socket, pid)
			_ ->
				GenServer.cast(pid, {:stop})
		end
	end

end
