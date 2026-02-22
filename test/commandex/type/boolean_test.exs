defmodule Commandex.Type.BooleanTest do
  use ExUnit.Case

  alias Commandex.Type.Boolean, as: BooleanType

  test "casts booleans" do
    assert BooleanType.cast(true) == {:ok, true}
    assert BooleanType.cast(false) == {:ok, false}
  end

  test "casts string booleans" do
    assert BooleanType.cast("true") == {:ok, true}
    assert BooleanType.cast("false") == {:ok, false}
  end

  test "casts numeric booleans" do
    assert BooleanType.cast(1) == {:ok, true}
    assert BooleanType.cast(0) == {:ok, false}
    assert BooleanType.cast("1") == {:ok, true}
    assert BooleanType.cast("0") == {:ok, false}
  end

  test "casts atom booleans" do
    assert BooleanType.cast(true) == {:ok, true}
    assert BooleanType.cast(false) == {:ok, false}
  end

  test "rejects other values" do
    assert BooleanType.cast("yes") == :error
    assert BooleanType.cast(2) == :error
  end
end
