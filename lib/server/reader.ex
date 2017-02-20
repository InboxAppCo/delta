defmodule Delta.Server.Reader do
	use GenServer
	alias Socket.Web
	alias Delta.Server.Processor

	def start_link(_delta, socket) do
		GenServer.start_link(__MODULE__, [socket])
	end

	def init([socket]) do
		self()
		|> send(:read)
		{:ok, socket}
	end

	def handle_info(:read, socket) do
		loop(socket)
		{:stop, :normal, socket}
	end

	def loop(socket) do
		case read(socket) do
			:stop ->
				Processor.stop(socket)
				:skip
			:loop -> loop(socket)
		end
	end

	def read(socket) do
		socket
		|> Web.recv
		|> handle_payload(socket)
	end

	defp handle_payload({:ok, {type, data}}, socket) when type == :text or type == :binary do
		Processor.process(socket, data)
		:loop
	end

	defp handle_payload({:ok, {:ping, _}}, _socket) do
		:loop
	end

	defp handle_payload({:ok, :close}, _socket) do
		:stop
	end

	defp handle_payload({:ok, _body}, _socket) do
		:stop
	end

	defp handle_payload(payload, _socket) do
		IO.inspect(payload)
		:stop
	end

	def terminate(reason, socket) do
		socket
		|> Web.close
		{reason, socket}
	end


end
