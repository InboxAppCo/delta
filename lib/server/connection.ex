defmodule Delta.Connection.Supervisor do
	use Supervisor

	def start_link(delta, port) do
		Supervisor.start_link(__MODULE__, delta, name: name(port))
	end

	def init(delta) do
		children = [
			supervisor(Delta.Connection, [delta], restart: :temporary)
		]
		supervise(children, strategy: :simple_one_for_one)
	end

	def start_child(port, socket) do
		Supervisor.start_child(name(port), [socket])
	end

	defp name(port) do
		{:global, {Node.self(), __MODULE__, port}}
	end
end

# defmodule Delta.Connection do
# 	use Supervisor
#
# 	def start_link(handlers, socket) do
# 		Supervisor.start_link(__MODULE__, [handlers, socket])
# 	end
#
# 	def init([handlers, socket]) do
# 		children = [
# 			worker(Delta.Connection.Reader, [handlers, socket], restart: :temporary),
# 			# worker(Delta.Connection.Processor, [socket], restart: :temporary),
# 		]
# 		supervise(children, strategy: :one_for_all)
# 	end
#
# end

defmodule Delta.Connection do
	use GenServer
	alias Socket.Web


	def start_link(delta, socket) do
		{:ok, processor} = Delta.Connection.Processor.start_link(delta, socket)
		GenServer.start_link(__MODULE__, [processor, socket])
	end

	def init([processor, socket]) do
		self()
		|> send(:read)
		{:ok, %{
			processor: processor,
			socket: socket,
		}}
	end

	def handle_info(:read, state = %{socket: socket}) do
		self()
		|> send(:read)
		socket
		|> Web.recv
		|> handle_payload(state)
	end

	defp handle_payload({:ok, {:text, data}}, state) do
		Delta.Connection.Processor.process(state.processor, data)
		{:noreply, state}
	end

	defp handle_payload({:ok, body}, state) do
		IO.inspect(body)
		{:noreply, state}
	end

	defp handle_payload(payload, state) do
		IO.inspect(payload)
		{:stop, :normal, state}
	end

	def terminate(reason, state) do
		{reason, state}
	end

end

defmodule Delta.Connection.Processor do
	 use GenServer
	 alias Socket.Web

	 def start_link(delta, socket) do
	 	GenServer.start_link(__MODULE__, [delta, socket])
	 end

	 def init([delta, socket]) do
		{:ok, data} = delta.handle_connect(socket)
		{:ok, %{
			socket: socket,
			delta: delta,
			data: data,
		}}
	 end

	 def process(pid, msg) do
		 send(pid, {:process, msg})
	 end

	 def handle_info({:process, msg}, state) do
		 %{
			 "key" => key,
			 "action" => action,
			 "body" => body,
		 } = Poison.decode!(msg)
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

	 defp format(response, body) do
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

 	def terminate(reason, state) do
 		{reason, state}
 	end

end
