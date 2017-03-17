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
				case mutation(mutation, user) do
					{:error, msg} -> {:error, msg, state}
					mut -> {:reply, %{
						"$merge" => mut.merge,
						"$delete" => mut.delete,
					}, state}
				end
			end

			def handle_command({"delta.broadcast.join", body, _version}, socket, state = %{user: user}) do
				:pg2.create(:broadcast)
				:pg2.join(:broadcast, self())
				{:reply, true, state}
			end

			def handle_command({"delta.broadcast", body, _version}, socket, state = %{user: user}) do
				merge = Map.get(body, "$merge", %{})
				delete = Map.get(body, "$delete", %{})
				mutation = Mutation.new(merge, delete)
				:broadcast
				|> :pg2.get_members
				|> IO.inspect
				|> Enum.each(&send({:mutation, UUID.ascending(), mutation}, &1))


				{:reply, true, state}
			end

			def handle_command({"delta.sync", body = %{"offset" => offset}, _version}, socket, state) do
				batch = Map.get(body, "batch", 1)
				result =
					read()
					|> Queue.sync(state.user, offset)
					|> Stream.chunk(batch, batch, [])
					|> Stream.map(fn mutations ->
						mutations |> Enum.reduce({"", Mutation.new}, fn {key, value}, {_, collect}-> {key, Mutation.combine(collect, value)} end)
					end)
					|> Enum.reduce(offset, fn {key, value}, _ ->
						"delta.mutation"
						|> Processor.format_cmd(%{
							"$merge": value.merge,
							"$delete": value.delete,
						}, 1, key)
						|> Processor.send_raw(socket)
						key
					end)
				{:reply, result, state}
			end

		end
	end
end
