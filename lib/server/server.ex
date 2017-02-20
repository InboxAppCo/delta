defmodule Delta.Server do
	use Supervisor

	def start_link(delta, port) do
		Supervisor.start_link(__MODULE__, [delta, port])
	end

	def init([delta, port]) do
		children = [
			worker(Task, [Delta.Server.Listener, :accept, [port]]),
			supervisor(Registry, [:unique, :delta_processors]),
			Delta.Supervisor.spec(delta, Delta.Server.Reader),
			Delta.Supervisor.spec(delta, Delta.Server.Processor),
		]
		supervise(children, strategy: :one_for_one)
	end

end
