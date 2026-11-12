defmodule Commandex.Type.DateTest do
  use ExUnit.Case

  alias Commandex.Type.Date, as: DateType

  test "casts dates" do
    assert DateType.cast(~D[2026-01-31]) == {:ok, ~D[2026-01-31]}
  end

  test "casts ISO 8601 date strings" do
    assert DateType.cast("2026-01-31") == {:ok, ~D[2026-01-31]}
  end

  test "casts datetime strings to their date" do
    assert DateType.cast("2026-01-31T10:30:00") == {:ok, ~D[2026-01-31]}
    assert DateType.cast("2026-01-31 10:30:00Z") == {:ok, ~D[2026-01-31]}
  end

  test "casts naive datetimes to their date" do
    assert DateType.cast(~N[2026-01-31 10:30:00]) == {:ok, ~D[2026-01-31]}
  end

  test "casts datetimes to their date in UTC" do
    chicago = %{
      ~U[2026-01-31 21:00:00Z]
      | time_zone: "America/Chicago",
        zone_abbr: "CST",
        utc_offset: -21_600
    }

    assert DateType.cast(~U[2026-01-31 21:00:00Z]) == {:ok, ~D[2026-01-31]}
    assert DateType.cast(chicago) == {:ok, ~D[2026-02-01]}
  end

  test "rejects invalid dates" do
    assert DateType.cast("2026-02-30") == :error
    assert DateType.cast("01/31/2026") == :error
    assert DateType.cast("tomorrow") == :error
  end

  test "rejects other types" do
    assert DateType.cast(20_260_131) == :error
    assert DateType.cast(%{year: 2026, month: 1, day: 31}) == :error
  end
end
