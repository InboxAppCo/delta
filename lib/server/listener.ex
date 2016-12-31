defmodule Delta.Server.Listener do
	use GenServer
	alias Socket.Web
	alias Delta.UUID

	def start_link(port) do
		GenServer.start_link(__MODULE__, [port])
	end

	def init([port]) do
		server =
			port
			|> Web.listen!
		send(self, :loop)
		{:ok, {port, server}}
	end

	def handle_info(:loop, state = {port, server}) do
		socket =
			server
			|> Web.accept!
		socket
		|> Web.accept!
		Delta.Connection.Supervisor.start_child(port, socket)
		send(self, :loop)
		{:noreply, state}
	end

end
