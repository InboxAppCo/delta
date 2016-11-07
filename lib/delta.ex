defmodule Delta.Base do

		defmacro __using__(_opts) do
			quote do
				use Delta.Plugin.Mutation
				use Delta.Plugin.Query
				use Delta.Plugin.Watch

				# Module.register_attribute(__MODULE__, :interceptors, accumulate: true)
				@before_compile Delta.Base

			end
		end

		defmacro __before_compile__(_env) do
			quote do
				def interceptors, do: @interceptors || []
				def writes, do: @writes|| []
				def read, do: @read|| []
			end
		end
end

defmodule Delta.Test do
	use Delta.Base

	@interceptors [
		Delta.Test.Interceptor
	]
	@cassandra {Delta.Stores.Cassandra, %{}}

	@writes [
		@cassandra
	]

	@read {Delta.Stores.Cassandra, %{}}

end

defmodule Delta.Test.Interceptor do
	use Delta.Interceptor

	def intercept_write([], _user, _atom, mutation) do
		:ok
	end

end
