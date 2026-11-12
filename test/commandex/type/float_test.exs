defmodule Commandex.Type.FloatTest do
  use ExUnit.Case

  alias Commandex.Type.Float, as: FloatType

  test "casts floats" do
    assert FloatType.cast(3.14) == {:ok, 3.14}
  end

  test "casts integers to floats" do
    assert FloatType.cast(42) == {:ok, 42.0}
  end

  test "casts string floats" do
    assert FloatType.cast("3.14") == {:ok, 3.14}
  end

  test "rejects non-numeric strings" do
    assert FloatType.cast("abc") == :error
    assert FloatType.cast("3.14abc") == :error
  end

  test "rejects other types" do
    assert FloatType.cast(:atom) == :error
    assert FloatType.cast([1.0]) == :error
  end
end
