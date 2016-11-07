defmodule Delta.Plugin.Fact do
	defmacro __using__(_opts) do

		quote do
			use Delta.Base
			alias Delta.Fact
			alias Delta.Mutation

			def add_fact(s, p, o) do
				mut = Fact.add(s,p,o)
				writes
				|> Enum.each(&Mutation.write(mut, &1))
			end

			def query_fact(input) do
				Fact.query(read, input)
			end

		end
	end
end
