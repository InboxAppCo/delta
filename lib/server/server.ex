defmodule Delta.Server do
	use Supervisor

	def start_link(delta, port) do
		Supervisor.start_link(__MODULE__, [delta, port])
	end

	def init([delta, port]) do
		children = [
			worker(Task, [Delta.Server.Listener, :accept, [port]]),
			supervisor(Delta.Supervisor, [delta, Delta.Server.Connection])
		]
		supervise(children, strategy: :one_for_one)
	end

end
