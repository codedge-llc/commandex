defmodule Commandex.Type.Integer do
  @behaviour Commandex.Type

  @doc ~S"""
  ## Examples

      iex> cast(12)
      {:ok, 12}

      iex> cast("15")
      {:ok, 15}

      iex> cast("1.5")
      :error

      iex> cast(false)
      :error
  """
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
