defmodule Delta.Plugin.Mutation do
	defmacro __using__(_opts) do

		quote do
			alias Delta.Mutation
			alias Delta.Watch
			alias Delta.Queue
			@master "delta-master"

			def mutation(mut), do: mutation(mut, @master)

			def mutation(mut, user) do
				interceptors = interceptors()
				case Mutation.validate(mut, interceptors, user) do
					nil ->
						prepared = Mutation.prepare(mut, interceptors, :intercept_write, user)

						prepared
						|> Watch.notify

						queued =
							prepared
							|> Queue.write
							|> Mutation.combine(prepared)
						writes()
						|> Enum.each(fn store -> Mutation.write(queued, store) end)

						case Mutation.commit(prepared, interceptors, user) do
							:ok -> prepared
							nil -> prepared
							error -> error
						end

					error -> error
				end
			end

			def merge(path, value) do
				Mutation.new
				|> Mutation.merge(path, value)
				|> mutation(@master)
			end

			def delete(path) do
				Mutation.new
				|> Mutation.delete(path)
				|> mutation(@master)
			end

			def handle_command({"delta.mutation", body, _version}, socket, state = %{user: user}) do
				merge = Map.get(body, "$merge", %{})
				delete = Map.get(body, "$delete", %{})
				mutation = Mutation.new(merge, delete)
				result = mutation(mutation, user)
				{:reply, result, state}
			end

		end
	end
end
