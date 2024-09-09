defmodule Commandex.Type.Integer do
  @behaviour Commandex.Type

  @impl true
  def cast(value) when is_integer(value), do: {:ok, value}

  def cast(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  def cast(_value), do: :error
end
