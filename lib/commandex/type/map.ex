defmodule Commandex.Type.Map do
  @moduledoc """
  Casts values to maps.

  Accepts a map and returns it as given.
  """

  @behaviour Commandex.Type

  @type t :: map()

  @impl true
  @spec cast(term()) :: {:ok, map()} | :error
  def cast(value) when is_map(value), do: {:ok, value}
  def cast(_), do: :error
end
