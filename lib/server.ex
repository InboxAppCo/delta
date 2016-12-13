defmodule Delta.Server.Listener do
	use GenServer
	alias Socket.Web

	def start_link(handler, port) do
		GenServer.start_link(__MODULE__, [handler, port])
	end

	def init([handler, port]) do
		server =
			port
			|> Web.listen!
		send(self, {:loop})
		{:ok, {handler, server}}
	end

	def handle_info({:loop}, state = {handler, server}) do
		socket =
			server
			|> Web.accept!
		Delta.Server.start_socket(socket, handler)
		send(self, {:loop})
		{:noreply, state}
	end

end

defmodule Delta.Server do
	use Supervisor
	import Supervisor.Spec

	def start_link(args) do
		Supervisor.start_link(__MODULE__, args, name: __MODULE__)
	end

	def init(args) do
		children = [
			worker(Delta.Server.Listener, args, restart: :permanent)
		]
		supervise(children, strategy: :one_for_one)
	end

	def start_socket(socket, handler) do
		import Supervisor.Spec
		Supervisor.start_child(__MODULE__, worker(Delta.Socket, [socket, handler], restart: :temporary))
	end

end

defmodule Delta.Socket do
	use GenServer
	alias Socket.Web

	def start_link(socket, handler) do
		GenServer.start_link(__MODULE__, [socket, handler])
	end

	def init([socket, handler]) do
		socket
		|> Web.accept!
		send(self, {:loop})
		{:ok, {socket, handler, %{}}}
	end

	def handle_info({:loop}, state = {socket, handler, data}) do
		send(self, {:loop})
		next =
			socket
			|> Web.recv!
			|> process(state)
	end

	def process({:text, raw}, state = {socket, handler, data}) do
		case Poison.decode(raw) do
			{:ok, %{
				"action" => action,
				"body" => body,
				"key" => key,
			}} ->
				{action, body, next} = handler.handle_command(action, body, data)
				json =
					key
					|> response(action, body)
					|> Poison.encode!
				socket
				|> Web.send!({:text, json})
				{:noreply, {socket, handler, next}}
			_ ->
				{:stop, :normal, state}
		end
	end

	defp response(key, action, body) do
		action
		|> case do
			:reply -> %{
				action: "drs.response",
				body: body
			}
			:error -> %{
				action: "drs.error",
				body: %{
					message: body
				}
			}
		end
		|> Map.put(:key, key)
	end

	def reply({action, body, data}, socket) do
		json =
			action
			|> case do
					:reply -> %{
						action: "drs.response",
						body: body
					}
					:error -> %{
						action: "drs.error",
						body: %{
							message: body
						}
					}
				end
			|> Poison.encode!
		Socket.Web.send!(socket, {:text, json})
		data
	end

	def terminate(_, {socket, _, _}) do
		Socket.Web.close(socket, :normal)
	end
end

defmodule Delta.Socket.EchoSample do
	def handle_command(_, body, data) do
		{:reply, body, data}
	end
end
