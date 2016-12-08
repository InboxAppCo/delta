defmodule Delta.Plugin.Mutation do
	defmacro __using__(_opts) do

		quote do
			use Delta.Base
			alias Delta.Mutation
			alias Delta.Watch
			@master "delta-master"

			def mutation(mut), do: mutation(mut, @master)

			def mutation(mut, user) do
				prepared = Mutation.prepare(mut, interceptors, :intercept_write, user)

				prepared
				|> Watch.notify

				writes
				|> Enum.each(fn store -> Mutation.write(prepared, store) end)

				prepared
			end

		end
	end
end
