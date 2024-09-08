defmodule Commandex.Parameter do
  def cast(value, type, opts \\ [])

  def cast(:"$undefined", type, opts) do
    case Keyword.get(opts, :default) do
      nil ->
        case Keyword.get(opts, :required) do
          true -> {:error, :required}
          _ -> {:ok, :"$undefined"}
        end

      default ->
        cast(default, type, opts)
    end
  end

  def cast(value, :any, _opts), do: {:ok, value}

  def cast(value, :boolean, _opts) when is_boolean(value), do: {:ok, value}
  def cast("true", :boolean, _opts), do: {:ok, true}
  def cast("false", :boolean, _opts), do: {:ok, false}
  def cast(_value, :boolean, _opts), do: {:error, :invalid}

  def cast(value, :integer, _opts) when is_integer(value) do
    {:ok, value}
  end

  def cast(value, :integer, opts) when is_binary(value) do
    cast(String.to_integer(value), :integer, opts)
  end

  def cast(value, :string, _opts) when is_binary(value) do
    {:ok, value}
  end

  def cast(value, :string, opts) do
    cast(inspect(value), :string, opts)
  end

  def cast(_value, _type, _opts), do: {:error, :invalid}
end
