defmodule Delta.Stores.Memory do
	@behaviour Delta.Store

	alias Delta.Dynamic

	def init(agent) do
		%{
			agent: agent,
			merge: [],
			delete: [],
		}
	end

	def merge(state = %{merge: merge}, path, value) do
		%{
			state |
			merge: [{path, value} | merge],
		}
	end

	def delete(state, path) do
		state
	end

	def execute(state = %{agent: agent, merge: merge}) do
		merge
		|> Enum.each(fn {path, data} ->
			Agent.update(agent, &Dynamic.put(&1, path, data))
		end)
	end

	def get(state = %{agent: agent}, path) do
		Agent.get(agent, &Dynamic.get(&1, path))
	end
end
