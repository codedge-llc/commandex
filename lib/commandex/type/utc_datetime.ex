defmodule Commandex.Type.UtcDateTime do
  @moduledoc """
  Casts values to datetimes in UTC.

  Accepts a `DateTime`, a `NaiveDateTime`, or an ISO 8601 string. A value
  with an offset or a time zone is moved to UTC. A value without an offset
  is taken as UTC.

  This module keeps the microseconds as given. The `:utc_datetime` type
  drops them and the `:utc_datetime_usec` type sets their precision to
  6 digits.
  """

  @behaviour Commandex.Type

  @type t :: DateTime.t()

  @impl true
  @spec cast(term()) :: {:ok, DateTime.t()} | :error
  def cast(%DateTime{time_zone: "Etc/UTC"} = value), do: {:ok, value}
  def cast(%NaiveDateTime{} = value), do: {:ok, DateTime.from_naive!(value, "Etc/UTC")}

  def cast(%DateTime{} = value) do
    case value |> DateTime.to_unix(:microsecond) |> DateTime.from_unix(:microsecond) do
      {:ok, datetime} -> {:ok, datetime}
      {:error, _reason} -> :error
    end
  end

  def cast(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _reason} -> from_naive_datetime(value)
    end
  end

  def cast(_), do: :error

  @spec from_naive_datetime(String.t()) :: {:ok, DateTime.t()} | :error
  defp from_naive_datetime(value) do
    case Commandex.Type.NaiveDateTime.cast(value) do
      {:ok, naive_datetime} -> {:ok, DateTime.from_naive!(naive_datetime, "Etc/UTC")}
      :error -> :error
    end
  end
end
