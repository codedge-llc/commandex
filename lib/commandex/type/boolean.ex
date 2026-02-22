defmodule Commandex.Type.Boolean do
  @moduledoc """
  Casts values to booleans.
  """

  @behaviour Commandex.Type

  @type t :: boolean()

  @impl true
  @spec cast(term()) :: {:ok, boolean()} | :error
  def cast(value) when is_boolean(value), do: {:ok, value}
  def cast("true"), do: {:ok, true}
  def cast("false"), do: {:ok, false}
  def cast("1"), do: {:ok, true}
  def cast("0"), do: {:ok, false}
  def cast(1), do: {:ok, true}
  def cast(0), do: {:ok, false}
  def cast(_), do: :error
end
