defmodule Commandex.Type do
  @undefined :"$undefined"

  @callback cast(term) :: {:ok, term} | :error
  @callback validate(term) :: {:ok, term} | {:error, term, atom}

  # def cast(@undefined, type, opts) do
  #   case Keyword.get(opts, :default) do
  #     nil ->
  #       case Keyword.get(opts, :required) do
  #         true -> {:error, @undefined, :required}
  #         _ -> {:ok, @undefined}
  #       end

  #     default ->
  #       cast(default, type, opts)
  #   end
  # end

  def cast(@undefined, _type), do: {:ok, @undefined}

  def cast(value, :any), do: {:ok, value}

  def cast(value, :boolean) when is_boolean(value), do: {:ok, value}
  def cast(value, :boolean) when value in ~w(true 1), do: {:ok, true}
  def cast(value, :boolean) when value in ~w(false 0), do: {:ok, false}
  def cast(_value, :boolean), do: :error

  def cast(value, :float) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> :error
    end
  end

  def cast(value, :float) when is_float(value), do: {:ok, value}
  def cast(value, :float) when is_integer(value), do: {:ok, :erlang.float(value)}
  def cast(_, :float), do: :error

  def cast(value, :integer) when is_integer(value), do: {:ok, value}
  def cast(value, :integer) when is_binary(value), do: cast(String.to_integer(value), :integer)
  def cast(_value, :integer), do: :error

  def cast(value, :string) when is_binary(value), do: {:ok, value}
  def cast(_value, :string), do: :error

  def cast(value, {:array, type}) when is_list(value) do
    if Enum.all?(value, fn val -> cast(val, type) |> elem(0) == :ok end),
      do: {:ok, value},
      else: :error
  end

  def cast(_value, {:array, _type}), do: :error

  def cast(_value, _type), do: :error
end
