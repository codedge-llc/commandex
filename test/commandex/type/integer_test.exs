defmodule Commandex.Type.IntegerTest do
  use ExUnit.Case

  alias Commandex.Type.Integer, as: IntegerType

  test "casts integers" do
    assert IntegerType.cast(42) == {:ok, 42}
  end

  test "casts string integers" do
    assert IntegerType.cast("42") == {:ok, 42}
    assert IntegerType.cast("-10") == {:ok, -10}
  end

  test "casts floats by truncating" do
    assert IntegerType.cast(3.9) == {:ok, 3}
  end

  test "rejects non-numeric strings" do
    assert IntegerType.cast("abc") == :error
    assert IntegerType.cast("12abc") == :error
  end

  test "rejects other types" do
    assert IntegerType.cast(:atom) == :error
    assert IntegerType.cast([1]) == :error
  end
end
