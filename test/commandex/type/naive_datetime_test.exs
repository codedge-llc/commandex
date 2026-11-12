defmodule Commandex.Type.NaiveDateTimeTest do
  use ExUnit.Case

  alias Commandex.Type.NaiveDateTime, as: NaiveDateTimeType

  test "casts naive datetimes" do
    assert NaiveDateTimeType.cast(~N[2026-01-31 10:30:15]) == {:ok, ~N[2026-01-31 10:30:15]}
  end

  test "casts ISO 8601 strings" do
    assert NaiveDateTimeType.cast("2026-01-31T10:30:15") == {:ok, ~N[2026-01-31 10:30:15]}
    assert NaiveDateTimeType.cast("2026-01-31 10:30:15") == {:ok, ~N[2026-01-31 10:30:15]}
  end

  test "casts strings without seconds" do
    assert NaiveDateTimeType.cast("2026-01-31T10:30") == {:ok, ~N[2026-01-31 10:30:00]}
    assert NaiveDateTimeType.cast("2026-01-31 10:30") == {:ok, ~N[2026-01-31 10:30:00]}
  end

  test "ignores the offset in a string" do
    assert NaiveDateTimeType.cast("2026-01-31T10:30:15+02:00") == {:ok, ~N[2026-01-31 10:30:15]}
  end

  test "keeps the microseconds as given" do
    assert NaiveDateTimeType.cast("2026-01-31T10:30:15.123") ==
             {:ok, ~N[2026-01-31 10:30:15.123]}
  end

  test "casts datetimes to UTC" do
    chicago = %{
      ~U[2026-01-31 21:00:00Z]
      | time_zone: "America/Chicago",
        zone_abbr: "CST",
        utc_offset: -21_600
    }

    assert NaiveDateTimeType.cast(~U[2026-01-31 21:00:00Z]) == {:ok, ~N[2026-01-31 21:00:00]}
    assert NaiveDateTimeType.cast(chicago) == {:ok, ~N[2026-02-01 03:00:00.000000]}
  end

  test "rejects invalid datetimes" do
    assert NaiveDateTimeType.cast("2026-02-30T10:30:15") == :error
    assert NaiveDateTimeType.cast("2026-01-31T25:30") == :error
    assert NaiveDateTimeType.cast("2026-01-31") == :error
    assert NaiveDateTimeType.cast("yesterday at noon") == :error
  end

  test "rejects other types" do
    assert NaiveDateTimeType.cast(1_769_855_415) == :error
    assert NaiveDateTimeType.cast(~D[2026-01-31]) == :error
  end
end
