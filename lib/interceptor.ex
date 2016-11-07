defmodule Delta.Interceptor do

	defmacro __using__(_opts) do
		quote do
			@before_compile Delta.Interceptor
		end
	end

	defmacro __before_compile__(_env) do
		quote do
			def intercept_write(_, _, _, _) do
				:ok
			end

			def intercept_delivery(_, _, _, _) do
				:ok
			end

			def intercept_commit(_, _, _, _) do
				:ok
			end

			def resolve_query(_path, _user, _atom) do
				nil
			end
		end
	end

end
