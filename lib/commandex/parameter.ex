defmodule Commandex.Parameter do
  def cast(value, type, opts \\ [])

  def cast(nil, _type, opts) do
    case Keyword.get(opts, :default) do
      nil -> {:ok, nil}
      default -> {:ok, default}
    end
  end

  def cast(value, :boolean, _opts) when is_boolean(value), do: {:ok, value}
  def cast("true", :boolean, _opts), do: {:ok, true}
  def cast("false", :boolean, _opts), do: {:ok, false}

  def cast(value, :integer, _opts) when is_integer(value) do
    {:ok, value}
  end

  def cast(value, :integer, opts) when is_binary(value) do
    cast(String.to_integer(value), :integer, opts)
  end

  def cast(value, _type, _opts), do: {:ok, value}
end
