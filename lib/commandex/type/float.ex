defmodule Commandex.Type.Float do
  @moduledoc """
  Casts values to floats.
  """

  @behaviour Commandex.Type

  @type t :: float()

  @impl true
  @spec cast(term()) :: {:ok, float()} | :error
  def cast(value) when is_float(value), do: {:ok, value}
  def cast(value) when is_integer(value), do: {:ok, value / 1}

  def cast(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> :error
    end
  end

  def cast(_), do: :error
end
