defmodule Commandex.Type.String do
  @moduledoc """
  Casts values to strings.
  """

  @behaviour Commandex.Type

  @type t :: String.t()

  @impl true
  @spec cast(term()) :: {:ok, String.t()} | :error
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(value) when is_atom(value), do: {:ok, Atom.to_string(value)}
  def cast(value) when is_integer(value), do: {:ok, Integer.to_string(value)}
  def cast(value) when is_float(value), do: {:ok, Float.to_string(value)}
  def cast(_), do: :error
end
