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
		 # Parse message
		 parsed = Poison.decode!(msg)
		 key = Map.get(parsed, "key")
		 action = Map.get(parsed, "action")
		 body = Map.get(parsed, "body")
		 version = Map.get(parsed, "version", 0)

		 # Trigger handlers
		 {action, body, data} = state.delta.handle_command({action, body, version}, state.socket, state.data)
		 case action do
			 :error -> send_error(state.socket, key, body)
			 :reply -> send_response(state.socket, key, body)
			 _ -> :skip
		 end

		 {:noreply, %{
			 state |
			 data: data
		 }}
	 end

	 def handle_info(msg, state) do
	 	{:ok, data} = state.delta.handle_info(msg, state.socket, state.data)
		{:noreply, %{
			state |
			data: data
		}}
	 end

 	 def send_error(socket, key, message) do
		payload =
	 	 	%{
	 			key: key,
	 			action: "drs.error",
	 			body: %{
					message: message
				}
	 		}
 		send_raw(socket, payload)
 	 end

	 def send_response(socket, key, body) do
		payload =
		 	%{
				key: key,
				action: "drs.response",
				body: body
			}
		send_raw(payload, socket)
	 end

	 def send_cmd(socket, action, body, version, key \\ '') do
		 payload =
			%{
				key: key,
				action: action,
				body: body,
				version: version,
			}
		send_raw(socket, payload)
	 end

	 def send_raw(socket, payload) do
		 json = Poison.encode!(payload)
		 Web.send(socket, {:text, json})
	 end

 	def terminate(reason, state = %{data: data, delta: delta}) do
		delta.handle_disconnect(data)
 		{reason, state}
 	end

end
