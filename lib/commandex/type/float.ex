defmodule Commandex.Type.Float do
  @behaviour Commandex.Type

  @impl true
  def cast(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> :error
    end
  end

  def cast(value) when is_float(value), do: {:ok, value}
  def cast(value) when is_integer(value), do: {:ok, :erlang.float(value)}
  def cast(_), do: :error
end
