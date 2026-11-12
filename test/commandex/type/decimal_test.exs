defmodule Commandex.Type.DecimalTest do
  use ExUnit.Case

  alias Commandex.Type.Decimal, as: DecimalType

  test "casts decimals" do
    assert DecimalType.cast(Decimal.new("1.50")) == {:ok, Decimal.new("1.50")}
  end

  test "casts integers" do
    assert DecimalType.cast(42) == {:ok, Decimal.new(42)}
  end

  test "casts floats" do
    assert DecimalType.cast(1.5) == {:ok, Decimal.new("1.5")}
  end

  test "casts strings" do
    assert DecimalType.cast("1.50") == {:ok, Decimal.new("1.50")}
    assert DecimalType.cast("-42") == {:ok, Decimal.new("-42")}
    assert DecimalType.cast("1e3") == {:ok, Decimal.new("1e3")}
  end

  test "casts strings at the digit and exponent limits" do
    digits = String.duplicate("9", 34)

    assert DecimalType.cast(digits) == {:ok, Decimal.new(digits)}
    assert DecimalType.cast("1e6144") == {:ok, Decimal.new("1e6144")}
  end

  test "rejects strings over the digit and exponent limits" do
    assert DecimalType.cast(String.duplicate("9", 35)) == :error
    assert DecimalType.cast("1e6145") == :error
    assert DecimalType.cast("1e1000000000") == :error
  end

  test "rejects strings that are not numbers" do
    assert DecimalType.cast("1.0bad") == :error
    assert DecimalType.cast("abc") == :error
  end

  test "rejects NaN and infinity" do
    assert DecimalType.cast("NaN") == :error
    assert DecimalType.cast("Infinity") == :error
    assert DecimalType.cast("-Infinity") == :error
    assert DecimalType.cast(Decimal.new("NaN")) == :error
    assert DecimalType.cast(Decimal.new("Infinity")) == :error
  end

  test "rejects other types" do
    assert DecimalType.cast(:atom) == :error
    assert DecimalType.cast([1]) == :error
  end
end
