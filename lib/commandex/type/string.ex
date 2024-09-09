defmodule Commandex.Type.String do
  @behaviour Commandex.Type

  @doc ~S"""
  ## Examples

      iex> cast("thing")
      {:ok, "thing"}

      iex> cast(1234)
      :error
  """
  @impl true
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(_value), do: :error
end
