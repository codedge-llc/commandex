defmodule Commandex.TypeTest do
  use ExUnit.Case

  describe "cast/2 nil handling" do
    test "nil returns {:ok, nil} for all types" do
      for type <- [:any, :string, :integer, :float, :boolean, {:array, :string}] do
        assert Commandex.Type.cast(nil, type) == {:ok, nil}
      end
    end
  end

  describe "cast/2 :any" do
    test "passes through any value" do
      assert Commandex.Type.cast("hello", :any) == {:ok, "hello"}
      assert Commandex.Type.cast(42, :any) == {:ok, 42}
      assert Commandex.Type.cast({:tuple}, :any) == {:ok, {:tuple}}
    end
  end

  describe "Array type" do
    test "casts array of integers" do
      assert Commandex.Type.cast(["1", "2", "3"], {:array, :integer}) == {:ok, [1, 2, 3]}
    end

    test "casts array of strings" do
      assert Commandex.Type.cast([:a, :b], {:array, :string}) == {:ok, ["a", "b"]}
    end

    test "fails if any element fails" do
      assert Commandex.Type.cast(["1", "bad"], {:array, :integer}) == :error
    end

    test "rejects non-list" do
      assert Commandex.Type.cast("hello", {:array, :string}) == :error
    end

    test "handles empty list" do
      assert Commandex.Type.cast([], {:array, :integer}) == {:ok, []}
    end
  end

  describe "custom type module" do
    defmodule UpperString do
      @behaviour Commandex.Type

      @impl true
      def cast(value) when is_binary(value), do: {:ok, String.upcase(value)}
      def cast(_), do: :error
    end

    test "dispatches to custom module" do
      assert Commandex.Type.cast("hello", UpperString) == {:ok, "HELLO"}
    end

    test "custom module failure returns :error" do
      assert Commandex.Type.cast(123, UpperString) == :error
    end
  end
end
