defmodule Delta.Server.Listener do
	use GenServer
	alias Socket.Web
	alias Delta.UUID

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
		socket
		|> Web.accept!
		Delta.Server.start_socket(socket, handler)
		send(self, {:loop})
		{:noreply, state}
	end

end

defmodule Delta.Server do
	use Supervisor
	alias Delta.UUID
	import Supervisor.Spec

	def start_link(handler, port) do
		Supervisor.start_link(__MODULE__, [handler, port], name: __MODULE__)
	end

	def init(args) do
		children = [
			worker(Delta.Server.Listener, args, restart: :permanent)
		]
		supervise(children, strategy: :one_for_one)
	end

	def start_socket(socket, handler) do
		import Supervisor.Spec
		Supervisor.start_child(__MODULE__, worker(Delta.Socket, [socket, handler], id: UUID.ascending(), restart: :temporary))
	end

end

defmodule Delta.Socket do
	use GenServer
	alias Socket.Web
	alias Delta.UUID

	def start_link(socket, handler) do
		GenServer.start_link(__MODULE__, [socket, handler])
	end

	def init([socket, handler]) do
		send(self, {:loop})
		{:ok, handler } = handler.start_link(socket)
		{:ok, {socket, handler }}
	end

	def handle_info({:loop}, state = {socket, handler}) do
		send(self, {:loop})
		next =
			socket
			|> Web.recv!
			|> process(state)
	end

	def process({:close, _, _}, state) do
		{:stop, :normal, state}
	end

	def process(:close, state) do
		{:stop, :normal, state}
	end

	def process({:text, raw}, state = {socket, handler}) do
		case Poison.decode(raw) do
			{:ok, %{
				"action" => action,
				"body" => body,
				"key" => key,
			}} ->
				json =
					GenServer.call(handler, {action, body})
					|> Map.put(:key, key)
					|> Poison.encode!
				socket
				|> Web.send!({:text, json})
				{:noreply, state}
			_ ->
				{:stop, :normal, state}
		end
	end

	def terminate(_, {socket, _}) do
		Socket.Web.close(socket, :normal)
	end
end

defmodule Delta.Handler do
	quote do

	end
end

defmodule Delta.Socket.EchoSample do
	def handle_command(_, body, data) do
		{:reply, body, data}
	end
end
