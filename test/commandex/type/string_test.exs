defmodule Commandex.Type.StringTest do
  use ExUnit.Case

  alias Commandex.Type.String, as: StringType

  test "casts binaries" do
    assert StringType.cast("hello") == {:ok, "hello"}
  end

  test "rejects atoms" do
    assert StringType.cast(:hello) == :error
    assert StringType.cast(true) == :error
  end

  test "rejects numbers" do
    assert StringType.cast(42) == :error
    assert StringType.cast(3.14) == :error
  end

  test "rejects other types" do
    assert StringType.cast({:tuple}) == :error
    assert StringType.cast([1, 2]) == :error
  end
end
