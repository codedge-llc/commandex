defmodule Commandex.Type.Integer do
  @moduledoc """
  Casts values to integers.

  Accepts an integer or a string that holds an integer, such as `"42"`.
  A float is not valid.
  """

  @behaviour Commandex.Type

  @type t :: integer()

  @impl true
  @spec cast(term()) :: {:ok, integer()} | :error
  def cast(value) when is_integer(value), do: {:ok, value}

  def cast(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  def cast(_), do: :error
end
