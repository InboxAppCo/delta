defmodule Delta.Server.Listener do
	alias Socket.Web

	def accept(port) do
		server = port |> Web.listen!
		loop(server)
	end

	defp loop(server) do
		case server |> Web.accept do
			{:ok, socket = %{headers: %{"Connection" => "Upgrade"} } } ->
				case Web.accept!(socket, []) do
					_ ->
						Delta.Supervisor.start_child(Delta.Server.Processor, [socket])
						Delta.Supervisor.start_child(Delta.Server.Reader, [socket])
					_ -> :skip
				end
			{:ok, socket} -> Web.close(socket)
			_ -> :skip
		end
		loop(server)
	end

end
