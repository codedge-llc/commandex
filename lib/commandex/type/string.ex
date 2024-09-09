defmodule Commandex.Type.String do
  @behaviour Commandex.Type

  @impl true
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(_value), do: :error
end
