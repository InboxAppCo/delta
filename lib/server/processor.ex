defmodule Delta.Server.Processor do
	 use GenServer
	 alias Socket.Web

	 def start_link(delta, socket) do
	 	GenServer.start_link(__MODULE__, [delta, socket], name: via_tuple(socket))
	 end

	defp via_tuple(socket) do
		{:via, Registry, {:delta_processors, socket.key}}
	end

	 def init([delta, socket]) do
		{:ok, data} = delta.handle_connect(socket)
		{:ok, %{
			socket: socket,
			delta: delta,
			data: data,
		}}
	 end

	 def stop(socket) do
	 	socket
		|> via_tuple
		|> GenServer.stop
	 end

	 def process(socket, msg) do
		 socket
		 |> via_tuple
		 |> GenServer.cast({:process, msg})
	 end

	 def handle_cast({:process, msg}, state) do
		 parsed = Poison.decode!(msg)
		 action = Map.get(parsed, "action")
		 body = Map.get(parsed, "body")
		 key = Map.get(parsed, "key")
		 state.delta.handle_command(action, body, state.data)
		 |> write(key, state)
	 end

	 def handle_info(msg, state) do
	 	state.delta.handle_info(msg, state.data)
		|> write(state)
	 end

	 defp write(event, state), do: write(event, "", state)

	 defp write({response, body, data}, key, state) do
		 json =
			format(response, body)
			|> Map.put(:key, key)
			|> Poison.encode!
		case Web.send(state.socket, {:text, json}) do
			:ok ->
				{:noreply, %{
					state |
					data: data
				}}
			{:error, :closed} -> {:stop, :normal, state}
		end
	 end

	 def format(response, body) do
		 case response do
			 :error -> %{
				 action: "drs.error",
				 body: %{
					 message: body
				 },
			 }
			 :reply -> %{
				 action: "drs.response",
				 body: body
			 }
			 _ -> %{
				 action: response,
				 body: body,
			 }
		 end
	 end

 	def terminate(reason, state = %{data: data, delta: delta}) do
		delta.handle_disconnect(data)
 		{reason, state}
 	end

end
