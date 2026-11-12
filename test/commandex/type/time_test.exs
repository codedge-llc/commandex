defmodule Commandex.Type.TimeTest do
  use ExUnit.Case

  alias Commandex.Type.Time, as: TimeType

  test "casts times" do
    assert TimeType.cast(~T[10:30:15]) == {:ok, ~T[10:30:15]}
  end

  test "casts ISO 8601 time strings" do
    assert TimeType.cast("10:30:15") == {:ok, ~T[10:30:15]}
    assert TimeType.cast("T10:30:15") == {:ok, ~T[10:30:15]}
  end

  test "casts strings without seconds" do
    assert TimeType.cast("10:30") == {:ok, ~T[10:30:00]}
  end

  test "keeps the microseconds as given" do
    assert TimeType.cast("10:30:15.123") == {:ok, ~T[10:30:15.123]}
    assert TimeType.cast(~T[10:30:15.123456]) == {:ok, ~T[10:30:15.123456]}
  end

  test "rejects invalid times" do
    assert TimeType.cast("25:00:00") == :error
    assert TimeType.cast("25:00") == :error
    assert TimeType.cast("10:3") == :error
    assert TimeType.cast("noon") == :error
  end

  test "rejects other types" do
    assert TimeType.cast(1030) == :error
    assert TimeType.cast(%{hour: 10, minute: 30}) == :error
  end
end
