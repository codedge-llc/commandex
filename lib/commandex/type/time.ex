defmodule Commandex.Type.Time do
  @moduledoc """
  Casts values to times.

  Accepts a `Time` or an ISO 8601 string. A string can omit the seconds,
  such as `"10:30"`.

  This module keeps the microseconds as given. The `:time` type drops them
  and the `:time_usec` type sets their precision to 6 digits.
  """

  @behaviour Commandex.Type

  @type t :: Time.t()

  @impl true
  @spec cast(term()) :: {:ok, Time.t()} | :error
  def cast(%Time{} = value), do: {:ok, value}
  def cast(<<_hour::2-bytes, ?:, _minute::2-bytes>> = value), do: from_iso8601(value <> ":00")
  def cast(value) when is_binary(value), do: from_iso8601(value)
  def cast(_), do: :error

  @spec from_iso8601(String.t()) :: {:ok, Time.t()} | :error
  defp from_iso8601(value) do
    case Time.from_iso8601(value) do
      {:ok, time} -> {:ok, time}
      {:error, _reason} -> :error
    end
  end
end
