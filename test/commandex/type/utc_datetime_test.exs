defmodule Commandex.Type.UTCDateTimeTest do
  use ExUnit.Case

  alias Commandex.Type.UTCDateTime, as: UTCDateTimeType

  test "casts datetimes in UTC" do
    assert UTCDateTimeType.cast(~U[2026-01-31 10:30:15Z]) == {:ok, ~U[2026-01-31 10:30:15Z]}
  end

  test "moves datetimes in other time zones to UTC" do
    chicago = %{
      ~U[2026-01-31 21:00:00Z]
      | time_zone: "America/Chicago",
        zone_abbr: "CST",
        utc_offset: -21_600
    }

    assert UTCDateTimeType.cast(chicago) == {:ok, ~U[2026-02-01 03:00:00.000000Z]}
  end

  test "casts ISO 8601 strings" do
    assert UTCDateTimeType.cast("2026-01-31T10:30:15Z") == {:ok, ~U[2026-01-31 10:30:15Z]}
    assert UTCDateTimeType.cast("2026-01-31 10:30:15Z") == {:ok, ~U[2026-01-31 10:30:15Z]}
  end

  test "moves strings with an offset to UTC" do
    assert UTCDateTimeType.cast("2026-01-31T10:30:15+02:00") == {:ok, ~U[2026-01-31 08:30:15Z]}
  end

  test "takes strings without an offset as UTC" do
    assert UTCDateTimeType.cast("2026-01-31T10:30:15") == {:ok, ~U[2026-01-31 10:30:15Z]}
    assert UTCDateTimeType.cast("2026-01-31T10:30") == {:ok, ~U[2026-01-31 10:30:00Z]}
  end

  test "takes naive datetimes as UTC" do
    assert UTCDateTimeType.cast(~N[2026-01-31 10:30:15]) == {:ok, ~U[2026-01-31 10:30:15Z]}
  end

  test "keeps the microseconds as given" do
    assert UTCDateTimeType.cast("2026-01-31T10:30:15.123Z") ==
             {:ok, ~U[2026-01-31 10:30:15.123Z]}
  end

  test "rejects invalid datetimes" do
    assert UTCDateTimeType.cast("2026-02-30T10:30:15Z") == :error
    assert UTCDateTimeType.cast("2026-01-31") == :error
    assert UTCDateTimeType.cast("now") == :error
  end

  test "rejects other types" do
    assert UTCDateTimeType.cast(1_769_855_415) == :error
    assert UTCDateTimeType.cast(~D[2026-01-31]) == :error
  end
end
