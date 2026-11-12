defmodule Commandex.Type.String do
  @moduledoc """
  Casts values to strings.

  Accepts a binary and returns it as given. The `:string` and `:binary`
  types both use this module.
  """

  @behaviour Commandex.Type

  @type t :: String.t()

  @impl true
  @spec cast(term()) :: {:ok, String.t()} | :error
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(_), do: :error
end
