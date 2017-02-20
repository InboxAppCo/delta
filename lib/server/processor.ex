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
		 {action, body, data} =
			try do
				 state.delta.handle_command({action, body, version}, state.socket, state.data)
			rescue
				_ -> {:exception, "Fuck this!!!!", state.data}
			catch
 				_ -> {:exception, "Fuck this!!!!", state.data}
 				_,_ -> {:exception, "Fuck this!!!!", state.data}
			end
		 action
		 |> format(key, body)
		 |> send_raw(state.socket)

		 {:noreply, %{
			 state |
			 data: data
		 }}
	 end

	 def handle_info(msg, state) do
		 IO.inspect(msg)
	 	{:ok, data} = state.delta.handle_info(msg, state.socket, state.data)
		{:noreply, %{
			state |
			data: data
		}}
	 end

	 def format(action, key, body) do
	 	case action do
			 :error -> format_error(key, body)
			 :exception -> format_exception(key, body)
			 :reply -> format_response(key, body)
	 	end
	 end

 	 def format_error(key, message) do
 	 	%{
 			key: key,
 			action: "drs.error",
 			body: %{
				message: message
			}
 		}
 	 end

 	 def format_exception(key, message) do
 	 	%{
 			key: key,
 			action: "drs.exception",
 			body: %{
				message: message
			}
 		}
 	 end

	 def format_response(key, body) do
	 	%{
			key: key,
			action: "drs.response",
			body: body
		}
	 end

	 def format_cmd(action, body, version, key \\ '') do
		%{
			key: key,
			action: action,
			body: body,
			version: version,
		}
	 end

	 def send_raw(payload, socket) do
		 json = Poison.encode!(payload)
		 Web.send(socket, {:text, json})
	 end

 	def terminate(reason, state = %{data: data, delta: delta}) do
		delta.handle_disconnect(data)
 		{reason, state}
 	end

end
