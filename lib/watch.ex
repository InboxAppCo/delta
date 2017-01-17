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

	defp notify_atom(atom = {path, _body}) do
		mutation = atom |> Mutation.inflate
		:syn.publish(name(path), {:mutation, mutation})
	end

	def name(path) do
		{__MODULE__, path}
	end

	def watch_online(user, path) do
		user
		|> watch_root("user:watch:online", path)
	end

	def watch_all(user, path) do
		Delta.Mutation.combine(
			watch_root(user, "user:watch:offline", path),
			watch_root(user, "user:watch:online", path)
		)
	end

	defp watch_root(user, root, path) do
		joined = Enum.join(path, "/")
		Mutation.new
		|> Mutation.merge([root, user, joined], 1)
	end

	def unwatch_all(user, path) do
		joined = Enum.join(path, "/")
		Mutation.new
		|> Mutation.delete(["user:watch:online", user, joined])
		|> Mutation.delete(["user:watch:offline", user, joined])
	end

end
