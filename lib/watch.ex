defmodule Delta.Watch do
	alias Delta.Mutation

	def watch(path) do
		:syn.join(name(path), self)
	end

	def unwatch(path) do
		:syn.leave(name(path), self)
	end

	def notify(mutation) do
		mutation
		|> Mutation.atoms
		|> Enum.each(&notify_atom/1)
	end

	defp notify_atom(atom = {path, body}) do
		mutation = atom |> Mutation.inflate
		:syn.publish(name(path), {:mutation, mutation})
	end

	def name(path) do
		{__MODULE__, path}
	end

end
