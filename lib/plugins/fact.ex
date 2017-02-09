defmodule Delta.Plugin.Fact do
	defmacro __using__(_opts) do

		quote do
			alias Delta.Fact
			alias Delta.Mutation

			def add_fact(s, p, o) do
				mut = Fact.add(s,p,o)
				writes()
				|> Enum.each(&Mutation.write(mut, &1))
			end

			def query_fact(input) do
				read()
				|> Fact.query(input)
			end

		end
	end
end
