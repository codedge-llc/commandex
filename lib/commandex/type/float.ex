defmodule Commandex.Type.Float do
  @behaviour Commandex.Type

  @doc ~S"""
  ## Examples

      iex> cast(1.234)
      {:ok, 1.234}

      iex> cast("1.5")
      {:ok, 1.5}

      iex> cast("1.5.1")
      :error

      iex> cast(10)
      {:ok, 10.0}

      iex> cast(false)
      :error
  """
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
