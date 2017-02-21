defmodule Delta.Plugin.Mutation do
	defmacro __using__(_opts) do

		quote do
			alias Delta.Mutation
			alias Delta.Watch
			alias Delta.Queue
			alias Delta.UUID
			alias Delta.Server.Processor
			@master "delta-master"

			def mutation(mut), do: mutation(mut, @master)

			def mutation(mut, user) do
				interceptors = interceptors()
				case Mutation.validate(mut, interceptors, user) do
					nil ->
						key = UUID.ascending()

						prepared = Mutation.prepare(mut, interceptors, :intercept_write, user)

						prepared
						|> Watch.notify(key)

						queued =
							read()
							|> Queue.write(prepared, key)
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
				mutation(mutation, user)
				{:reply, true, state}
			end

			def handle_command({"delta.sync", body = %{"offset" => offset}, _version}, socket, state) do
				result =
					read()
					|> Queue.sync(state.user, offset)
					|> Enum.reduce(offset, fn {key, value}, _ ->
						merge = Map.get(value, "merge", %{})
						delete = Map.get(value, "delete", %{})
						"delta.mutation"
						|> Processor.format_cmd(%{
							"$merge": merge,
							"$delete": delete,
						}, 1, key)
						|> Processor.send_raw(socket)
						key
					end)
				{:reply, result, state}
			end

		end
	end
end
