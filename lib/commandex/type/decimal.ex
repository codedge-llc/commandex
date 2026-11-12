defmodule Commandex.Type.Decimal do
  @moduledoc """
  Casts values to decimals.

  Accepts a `Decimal`, an integer, a float, or a string. `NaN` and the
  infinity values are not valid.

  This type needs the optional `:decimal` package:

      {:decimal, "~> 3.0"}

  Decimal 2.x is not supported.
  """

  @behaviour Commandex.Type

  if Code.ensure_loaded?(Decimal) do
    @type t :: Decimal.t()

    # These limits are the defaults of Decimal 3.0. They are given here so
    # that a change of the defaults does not change the cast.
    @parse_opts [max_digits: 34, max_exponent: 6_144]

    @impl true
    @spec cast(term()) :: {:ok, Decimal.t()} | :error
    def cast(%Decimal{coef: coef} = value) when is_integer(coef), do: {:ok, value}
    def cast(value) when is_integer(value), do: {:ok, Decimal.new(value)}
    def cast(value) when is_float(value), do: {:ok, Decimal.from_float(value)}

    def cast(value) when is_binary(value) do
      case Decimal.parse(value, @parse_opts) do
        {%Decimal{coef: coef} = decimal, ""} when is_integer(coef) -> {:ok, decimal}
        _other -> :error
      end
    end

    def cast(_), do: :error
  else
    @type t :: term()

    @impl true
    @spec cast(term()) :: :error
    def cast(_), do: :error
  end
end
