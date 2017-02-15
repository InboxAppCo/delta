defmodule Delta.Server do
	use Supervisor

	def start_link(delta, port) do
		Supervisor.start_link(__MODULE__, [delta, port], name: name(port))
	end

	def init([delta, port]) do
		children = [
			worker(Delta.Server.Listener, [port], restart: :permanent),
			supervisor(Delta.Connection.Supervisor, [delta, port], restart: :permanent)
		]
		supervise(children, strategy: :one_for_one)
	end

	defp name(port) do
		{:global, {Node.self(), __MODULE__, port}}
	end

	def connection_sup do

	end
end
