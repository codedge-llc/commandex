defmodule Commandex.Type.StringTest do
  use ExUnit.Case

  alias Commandex.Type.String, as: StringType

  test "casts binaries" do
    assert StringType.cast("hello") == {:ok, "hello"}
  end

  test "casts atoms" do
    assert StringType.cast(:hello) == {:ok, "hello"}
  end

  test "casts integers" do
    assert StringType.cast(42) == {:ok, "42"}
  end

  test "casts floats" do
    assert StringType.cast(3.14) == {:ok, "3.14"}
  end

  test "rejects non-stringable types" do
    assert StringType.cast({:tuple}) == :error
    assert StringType.cast([1, 2]) == :error
  end
end
