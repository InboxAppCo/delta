defmodule Delta.UUID do
	@base 63
	@ascending "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz" |> String.split("") |> Enum.take(@base)
	@descending Enum.reverse(@ascending)
	@length 8
	@total @length + 12
	@descending_max "zzzzzzzzzzzzzzzzzzzz"
	@ascending_max "00000000000000000000"

	def descending_max, do: @descending_max
	def ascending_max, do: @ascending_max

	def descending() do
		descending_from(:os.system_time(:milli_seconds))
	end

	def descending_from(time) do
		generate(time, @descending)
	end

	def ascending() do
		ascending_from(:os.system_time(:milli_seconds))
	end

	def ascending_from(time) do
		generate(time, @ascending)
	end

	def generate(time, pool) do
		generate(time, pool, @total, [])
		|> Enum.join
	end

	# Random Part
	def generate(time, pool, count, collect) when count > @length do
		collect = [Enum.random(pool) | collect]
		generate(time, pool, count - 1, collect)
	end

	# Time Part
	def generate(time, pool, count, collect) when count > 0 do
		n = rem(time, @base)
		collect = [Enum.at(pool, n) | collect]
		generate(div(time, @base), pool, count - 1, collect)
	end

	def generate(_time, _pool, _count, collect) do
		collect
	end
end
