defmodule Delta.Server.Processor do
	 use GenServer
	 alias Socket.Web
	 import Logger

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

	 def handle_cast({:process, msg}, state = %{data: data}) do
		 # Parse message
		 parsed = Poison.decode!(msg)
		 key = Map.get(parsed, "key")
		 action = Map.get(parsed, "action")
		 body = Map.get(parsed, "body")
		 version = Map.get(parsed, "version", 0)
		 info(~s(
Request
action: #{action}
body: #{inspect(body)}
		 ))

		 {:ok, data} = state.delta.handle_precommand({action, body, version}, state.socket, data)

		 # Trigger handlers
		 {response, response_body, data} =
				 state.delta.handle_command({action, body, version}, state.socket, data)
			# try do
			# rescue
			# 	e -> {:exception, inspect(e), state.data}
			# catch
 		# 		e -> {:exception, inspect(e), state.data}
 		# 		_, e -> {:exception, inspect(e), state.data}
			# end

		 {:ok, data} = state.delta.handle_postcommand({action, body, version}, {response, response_body}, state.socket, data)

			info(~s(
Response
action: #{response}
body: #{inspect(response_body)}
			))

		 response
		 |> format(key, response_body, version)
		 |> send_raw(state.socket)

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

	 def format(action, key, body, version \\ 0) do
	 	case action do
			 :error -> format_cmd("drs.error", body, 0, key)
			 :exception -> format_cmd("drs.exception", body, 0, key)
			 :reply -> format_cmd("drs.response", body, version, key)
	 	end
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

 	def terminate(reason, state = %{data: data, delta: delta, socket: socket}) do
		delta.handle_disconnect(data)
		socket
		|> Web.close
 		{reason, state}
 	end

end
