defmodule Commandex.Type.Date do
  @moduledoc """
  Casts values to dates.

  Accepts a `Date`, a `NaiveDateTime`, a `DateTime`, or an ISO 8601 string.
  A value with a date and a time gives its date. A `DateTime` is moved to
  UTC first.
  """

  @behaviour Commandex.Type

  @type t :: Date.t()

  @impl true
  @spec cast(term()) :: {:ok, Date.t()} | :error
  def cast(%Date{} = value), do: {:ok, value}
  def cast(%NaiveDateTime{} = value), do: {:ok, NaiveDateTime.to_date(value)}

  def cast(%DateTime{} = value) do
    case Commandex.Type.UTCDateTime.cast(value) do
      {:ok, datetime} -> {:ok, DateTime.to_date(datetime)}
      :error -> :error
    end
  end

  def cast(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> from_naive_datetime(value)
    end
  end

  def cast(_), do: :error

  @spec from_naive_datetime(String.t()) :: {:ok, Date.t()} | :error
  defp from_naive_datetime(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive_datetime} -> {:ok, NaiveDateTime.to_date(naive_datetime)}
      {:error, _reason} -> :error
    end
  end
end
