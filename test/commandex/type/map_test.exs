defmodule Commandex.Type.MapTest do
  use ExUnit.Case

  alias Commandex.Type.Map, as: MapType

  test "casts maps" do
    assert MapType.cast(%{}) == {:ok, %{}}
    assert MapType.cast(%{"a" => 1, b: "two"}) == {:ok, %{"a" => 1, b: "two"}}
  end

  test "rejects other types" do
    assert MapType.cast(a: 1) == :error
    assert MapType.cast("a=1") == :error
    assert MapType.cast([]) == :error
  end
end
