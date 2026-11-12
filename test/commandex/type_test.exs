defmodule Commandex.TypeTest do
  use ExUnit.Case
  doctest Commandex.Type

  describe "cast/2 nil handling" do
    test "nil returns {:ok, nil} for all types" do
      types = [
        :any,
        :binary,
        :boolean,
        :date,
        :decimal,
        :float,
        :integer,
        :map,
        :naive_datetime,
        :naive_datetime_usec,
        :string,
        :time,
        :time_usec,
        :utc_datetime,
        :utc_datetime_usec,
        {:array, :string},
        {:map, :integer}
      ]

      for type <- types do
        assert Commandex.Type.cast(type, nil) == {:ok, nil}
      end
    end
  end

  describe "base?/1" do
    test "is true for each built-in atom" do
      assert Commandex.Type.base?(:string)
      assert Commandex.Type.base?(:utc_datetime_usec)
    end

    test "is false for other values" do
      refute Commandex.Type.base?(:enum)
      refute Commandex.Type.base?({:array, :string})
      refute Commandex.Type.base?(String)
    end
  end

  describe "cast/2 :any" do
    test "passes through any value" do
      assert Commandex.Type.cast(:any, "hello") == {:ok, "hello"}
      assert Commandex.Type.cast(:any, 42) == {:ok, 42}
      assert Commandex.Type.cast(:any, {:tuple}) == {:ok, {:tuple}}
    end
  end

  describe "Array type" do
    test "casts array of integers" do
      assert Commandex.Type.cast({:array, :integer}, ["1", "2", "3"]) == {:ok, [1, 2, 3]}
    end

    test "casts array of strings" do
      assert Commandex.Type.cast({:array, :string}, ["a", "b"]) == {:ok, ["a", "b"]}
    end

    test "casts nested arrays" do
      type = {:array, {:array, :integer}}

      assert Commandex.Type.cast(type, [["1"], [2, "3"]]) == {:ok, [[1], [2, 3]]}
    end

    test "keeps nil elements" do
      assert Commandex.Type.cast({:array, :integer}, [nil, "1"]) == {:ok, [nil, 1]}
    end

    test "fails if any element fails" do
      assert Commandex.Type.cast({:array, :integer}, ["1", "bad"]) == :error
      assert Commandex.Type.cast({:array, :string}, [:a, :b]) == :error
    end

    test "rejects non-list" do
      assert Commandex.Type.cast({:array, :string}, "hello") == :error
    end

    test "handles empty list" do
      assert Commandex.Type.cast({:array, :integer}, []) == {:ok, []}
    end
  end

  describe "to_spec/1" do
    defp spec_string(type), do: Macro.to_string(Commandex.Type.to_spec(type))

    test ":any is term()" do
      assert spec_string(:any) == "term()"
    end

    test "a built-in type is its spec or nil" do
      assert spec_string(:binary) == "binary() | nil"
      assert spec_string(:boolean) == "boolean() | nil"
      assert spec_string(:date) == "Date.t() | nil"
      assert spec_string(:decimal) == "Decimal.t() | nil"
      assert spec_string(:float) == "float() | nil"
      assert spec_string(:integer) == "integer() | nil"
      assert spec_string(:map) == "map() | nil"
      assert spec_string(:naive_datetime) == "NaiveDateTime.t() | nil"
      assert spec_string(:naive_datetime_usec) == "NaiveDateTime.t() | nil"
      assert spec_string(:string) == "String.t() | nil"
      assert spec_string(:time) == "Time.t() | nil"
      assert spec_string(:time_usec) == "Time.t() | nil"
      assert spec_string(:utc_datetime) == "DateTime.t() | nil"
      assert spec_string(:utc_datetime_usec) == "DateTime.t() | nil"
    end

    test "an array is a list of the inner spec" do
      assert spec_string({:array, :string}) == "[String.t()] | nil"
      assert spec_string({:array, :any}) == "[term()] | nil"
    end

    test "a map has values of the inner spec" do
      assert spec_string({:map, :integer}) == "%{optional(term()) => integer()} | nil"
    end

    test "nested types compile" do
      assert spec_string({:array, {:array, :integer}}) == "[[integer()]] | nil"

      assert spec_string({:map, {:array, :date}}) ==
               "%{optional(term()) => [Date.t()]} | nil"
    end

    test "a custom type module is its t() type" do
      assert spec_string(MyApp.Types.Color) == "MyApp.Types.Color.t() | nil"
      assert spec_string({:array, MyApp.Types.Color}) == "[MyApp.Types.Color.t()] | nil"
    end

    test "a type with options is the t() type of its module" do
      type = {:parameterized, {MyApp.Types.Enum, %{"ASC" => :asc}}}

      assert spec_string(type) == "MyApp.Types.Enum.t() | nil"
      assert spec_string({:map, type}) == "%{optional(term()) => MyApp.Types.Enum.t()} | nil"
    end
  end

  describe "cast/2 :binary" do
    test "accepts binaries only" do
      assert Commandex.Type.cast(:binary, <<0, 255>>) == {:ok, <<0, 255>>}
      assert Commandex.Type.cast(:binary, "  ") == {:ok, "  "}
      assert Commandex.Type.cast(:binary, 42) == :error
    end
  end

  describe "cast/2 :map" do
    test "accepts maps only" do
      assert Commandex.Type.cast(:map, %{"a" => 1}) == {:ok, %{"a" => 1}}
      assert Commandex.Type.cast(:map, a: 1) == :error
    end
  end

  describe "cast/2 {:map, type}" do
    test "casts each value and keeps the keys" do
      type = {:map, :integer}

      assert Commandex.Type.cast(type, %{"a" => "1", b: 2}) == {:ok, %{"a" => 1, b: 2}}
    end

    test "casts nested types" do
      type = {:map, {:array, :date}}

      assert Commandex.Type.cast(type, %{"days" => ["2026-01-31"]}) ==
               {:ok, %{"days" => [~D[2026-01-31]]}}
    end

    test "keeps nil values" do
      assert Commandex.Type.cast({:map, :integer}, %{"a" => nil}) == {:ok, %{"a" => nil}}
    end

    test "fails if any value fails" do
      assert Commandex.Type.cast({:map, :integer}, %{"a" => "1", "b" => "bad"}) == :error
    end

    test "rejects a value that is not a map" do
      assert Commandex.Type.cast({:map, :integer}, [{"a", 1}]) == :error
    end

    test "handles an empty map" do
      assert Commandex.Type.cast({:map, :integer}, %{}) == {:ok, %{}}
    end
  end

  describe "cast/2 :date" do
    test "casts a date string" do
      assert Commandex.Type.cast(:date, "2026-01-31") == {:ok, ~D[2026-01-31]}
      assert Commandex.Type.cast(:date, "2026-02-30") == :error
    end
  end

  describe "cast/2 :decimal" do
    test "casts a decimal string" do
      assert Commandex.Type.cast(:decimal, "1.50") == {:ok, Decimal.new("1.50")}
      assert Commandex.Type.cast(:decimal, "NaN") == :error
    end
  end

  describe "cast/2 time types" do
    test ":time drops the microseconds" do
      assert Commandex.Type.cast(:time, "10:30:15.123") == {:ok, ~T[10:30:15]}
      assert Commandex.Type.cast(:time, ~T[10:30:15.123456]) == {:ok, ~T[10:30:15]}
    end

    test ":time_usec has a precision of 6 digits" do
      assert Commandex.Type.cast(:time_usec, "10:30:15") == {:ok, ~T[10:30:15.000000]}
      assert Commandex.Type.cast(:time_usec, "10:30:15.123") == {:ok, ~T[10:30:15.123000]}
    end

    test "an invalid value fails" do
      assert Commandex.Type.cast(:time, "25:00:00") == :error
      assert Commandex.Type.cast(:time_usec, "25:00:00") == :error
    end
  end

  describe "cast/2 naive datetime types" do
    test ":naive_datetime drops the microseconds" do
      assert Commandex.Type.cast(:naive_datetime, "2026-01-31T10:30:15.123") ==
               {:ok, ~N[2026-01-31 10:30:15]}
    end

    test ":naive_datetime_usec has a precision of 6 digits" do
      assert Commandex.Type.cast(:naive_datetime_usec, "2026-01-31T10:30:15") ==
               {:ok, ~N[2026-01-31 10:30:15.000000]}

      assert Commandex.Type.cast(:naive_datetime_usec, "2026-01-31T10:30:15.123") ==
               {:ok, ~N[2026-01-31 10:30:15.123000]}
    end

    test "an invalid value fails" do
      assert Commandex.Type.cast(:naive_datetime, "2026-01-31") == :error
      assert Commandex.Type.cast(:naive_datetime_usec, "2026-01-31") == :error
    end
  end

  describe "cast/2 UTC datetime types" do
    test ":utc_datetime drops the microseconds" do
      assert Commandex.Type.cast(:utc_datetime, "2026-01-31T10:30:15.123Z") ==
               {:ok, ~U[2026-01-31 10:30:15Z]}
    end

    test ":utc_datetime_usec has a precision of 6 digits" do
      assert Commandex.Type.cast(:utc_datetime_usec, "2026-01-31T10:30:15Z") ==
               {:ok, ~U[2026-01-31 10:30:15.000000Z]}

      assert Commandex.Type.cast(:utc_datetime_usec, "2026-01-31T10:30:15.123+02:00") ==
               {:ok, ~U[2026-01-31 08:30:15.123000Z]}
    end

    test "an invalid value fails" do
      assert Commandex.Type.cast(:utc_datetime, "2026-01-31") == :error
      assert Commandex.Type.cast(:utc_datetime_usec, "2026-01-31") == :error
    end
  end

  describe "custom type module" do
    defmodule UpperString do
      @behaviour Commandex.Type

      @impl true
      def cast(value) when is_binary(value), do: {:ok, String.upcase(value)}
      def cast(_), do: :error
    end

    defmodule KeywordError do
      @behaviour Commandex.Type

      @impl true
      def cast(value) when is_binary(value), do: {:ok, value}
      def cast(_), do: {:error, message: "must be a string"}
    end

    test "dispatches to custom module" do
      assert Commandex.Type.cast(UpperString, "hello") == {:ok, "HELLO"}
    end

    test "custom module failure returns :error" do
      assert Commandex.Type.cast(UpperString, 123) == :error
    end

    test "an {:error, keyword} result returns :error" do
      assert Commandex.Type.cast(KeywordError, "hello") == {:ok, "hello"}
      assert Commandex.Type.cast(KeywordError, 123) == :error
    end

    test "does not pass nil to the custom module" do
      assert Commandex.Type.cast(UpperString, nil) == {:ok, nil}
    end
  end

  describe "custom type module with options" do
    defmodule Prefix do
      @behaviour Commandex.Type

      @impl true
      def init(opts), do: Keyword.fetch!(opts, :prefix)

      @impl true
      def cast(value, prefix) when is_binary(value), do: {:ok, prefix <> value}
      def cast(_value, _prefix), do: {:error, message: "must be a string"}
    end

    test "calls cast/2 with the params" do
      type = {:parameterized, {Prefix, "id-"}}

      assert Commandex.Type.cast(type, "42") == {:ok, "id-42"}
      assert Commandex.Type.cast({:array, type}, ["1", "2"]) == {:ok, ["id-1", "id-2"]}
    end

    test "a failure returns :error" do
      assert Commandex.Type.cast({:parameterized, {Prefix, "id-"}}, 42) == :error
    end

    test "does not pass nil to the custom module" do
      assert Commandex.Type.cast({:parameterized, {Prefix, "id-"}}, nil) == {:ok, nil}
    end
  end
end
