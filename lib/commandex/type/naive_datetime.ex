defmodule Commandex.Type.NaiveDateTime do
  @moduledoc """
  Casts values to naive datetimes.

  Accepts a `NaiveDateTime`, a `DateTime`, or an ISO 8601 string. A string
  can omit the seconds, such as `"2026-01-31T10:30"`. A `DateTime` is moved
  to UTC first, and an offset in a string is ignored.

  This module keeps the microseconds as given. The `:naive_datetime` type
  drops them and the `:naive_datetime_usec` type sets their precision to
  6 digits.
  """

  @behaviour Commandex.Type

  @type t :: NaiveDateTime.t()

  @impl true
  @spec cast(term()) :: {:ok, NaiveDateTime.t()} | :error
  def cast(%NaiveDateTime{} = value), do: {:ok, value}

  def cast(%DateTime{} = value) do
    case Commandex.Type.UtcDateTime.cast(value) do
      {:ok, datetime} -> {:ok, DateTime.to_naive(datetime)}
      :error -> :error
    end
  end

  def cast(<<_date::10-bytes, separator, _hour::2-bytes, ?:, _minute::2-bytes>> = value)
      when separator in [?\s, ?T] do
    from_iso8601(value <> ":00")
  end

  def cast(value) when is_binary(value), do: from_iso8601(value)
  def cast(_), do: :error

  @spec from_iso8601(String.t()) :: {:ok, NaiveDateTime.t()} | :error
  defp from_iso8601(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive_datetime} -> {:ok, naive_datetime}
      {:error, _reason} -> :error
    end
  end
end
