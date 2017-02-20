defmodule Delta.Server.Listener do
	alias Socket.Web

	def accept(port) do
		server = port |> Web.listen!
		loop(server)
	end

	defp loop(server) do
		socket = server |> Web.accept!
		socket |> Web.accept!
		Delta.Supervisor.start_child(Delta.Server.Processor, [socket])
		Delta.Supervisor.start_child(Delta.Server.Reader, [socket])
		loop(server)
	end

end
