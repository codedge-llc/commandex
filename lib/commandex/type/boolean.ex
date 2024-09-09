defmodule Commandex.Type.Boolean do
  @behaviour Commandex.Type

  @impl true
  def cast(value) when is_boolean(value), do: {:ok, value}
  def cast(value) when value in ~w(true 1), do: {:ok, true}
  def cast(value) when value in ~w(false 0), do: {:ok, false}
  def cast(_value), do: :error
end
