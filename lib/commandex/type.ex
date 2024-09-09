defmodule Commandex.Type do
  @undefined :"$undefined"

  @callback cast(term) :: {:ok, term} | :error

  def cast(@undefined, _type), do: {:ok, @undefined}

  def cast(value, :array), do: cast(value, {:array, :any})

  def cast(value, {:array, type}) when is_list(value) do
    if Enum.any?(value, fn val -> cast(val, type) == :error end),
      do: :error,
      else: {:ok, value}
  end

  def cast(_value, {:array, _type}), do: :error

  def cast(value, :any), do: {:ok, value}
  def cast(value, :boolean), do: Commandex.Type.Boolean.cast(value)
  def cast(value, :float), do: Commandex.Type.Float.cast(value)
  def cast(value, :integer), do: Commandex.Type.Integer.cast(value)
  def cast(value, :string), do: Commandex.Type.String.cast(value)
  def cast(value, module) when is_atom(module), do: module.cast(value)
  def cast(_value, _type), do: :error
end
