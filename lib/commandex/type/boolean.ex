defmodule Commandex.Type.Boolean do
  @moduledoc false

  @behaviour Commandex.Type

  @doc ~S"""
  ## Examples

      iex> cast(true)
      {:ok, true}

      iex> cast(false)
      {:ok, false}

      iex> cast("true")
      {:ok, true}

      iex> cast("false")
      {:ok, false}

      iex> cast("1")
      {:ok, true}

      iex> cast("0")
      {:ok, false}

      iex> cast("not-boolean")
      :error
  """
  @impl true
  def cast(value) when is_boolean(value), do: {:ok, value}
  def cast(value) when value in ~w(true 1), do: {:ok, true}
  def cast(value) when value in ~w(false 0), do: {:ok, false}
  def cast(_value), do: :error
end
