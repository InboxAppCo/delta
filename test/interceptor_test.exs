defmodule Delta.InterceptorTest do
	use ExUnit.Case
	alias Delta.Mutation

	@interceptors [ Delta.InterceptorTest.Interceptor ]

	test "prepare" do
		mutation =
			Mutation.new
			|> Mutation.merge(["a", "b", "field"], true)
		compare =
			mutation
			|> Mutation.merge(["a", "b", "insert"], true)
		assert Delta.Interceptor.prepare(@interceptors, mutation, "user") == compare
	end

	test "validate" do
		trigger(:validate)
	end

	test "commit" do
		trigger(:commit)
	end

	test "deliver" do
		trigger(:deliver)
	end

	defp trigger(type, compare \\ nil) do
		mutation =
			Mutation.new
			|> Mutation.merge(["a", "c", "field"], true)
		assert apply(Delta.Interceptor, type, [@interceptors, mutation, "user"]) == {:error, :failed}
		mutation =
			Mutation.new
			|> Mutation.merge(["a", "b", "field"], true)
		assert apply(Delta.Interceptor, type, [@interceptors, mutation, "user"]) == compare
	end
end

defmodule Delta.InterceptorTest.Interceptor do
	use Delta.Interceptor
	alias Delta.Mutation

	def validate_write(["a", "b"], _user, _layer, _mutation) do
		:ok
	end

	def validate_write(["a", "c"], _user, _layer, _mutation) do
		{:error, :failed}
	end

	def intercept_commit(["a", "b"], _user, _layer, _mutation) do
		:ok
	end

	def intercept_commit(["a", "c"], _user, _layer, _mutation) do
		{:error, :failed}
	end

	def intercept_delivery(["a", "b"], _user, _layer, _mutation) do
		:ok
	end

	def intercept_delivery(["a", "c"], _user, _layer, _mutation) do
		{:error, :failed}
	end

	def intercept_write(["a", "b"], _user, _layer, mutation) do
		mutation = Mutation.merge(mutation, ["a", "b", "insert"], true)
		{:ok, mutation}
	end
end
