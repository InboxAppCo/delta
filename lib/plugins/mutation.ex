defmodule Delta.Plugin.Mutation do
	defmacro __using__(_opts) do

		quote do
			alias Delta.Mutation
			alias Delta.Watch
			@master "delta-master"

			def mutation(mut), do: mutation(mut, @master)

			def mutation(mut, user) do
				prepared = Mutation.prepare(mut, interceptors, :intercept_write, user)

				prepared
				|> Watch.notify

				prepared
			end
		end
	end
end
