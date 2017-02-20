defmodule Delta.Supervisor do
	use Supervisor

	def start_link(delta, module) do
		Supervisor.start_link(__MODULE__, [delta, module], name: module)
	end

	def init([delta, module]) do
		children = [
			worker(module, [delta], restart: :transient)
		]
		supervise(children, strategy: :simple_one_for_one)
	end

	def start_child(module, args) do
		Supervisor.start_child(module, args)
	end

	def spec(delta, module) do
		import Supervisor.Spec
		supervisor(__MODULE__, [delta, module], id: module)
	end

end
