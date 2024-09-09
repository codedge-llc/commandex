defmodule Commandex.Type do
  @undefined :"$undefined"

  @callback cast(term) :: {:ok, term} | :error

  @doc ~S"""
  Casts value for given type.

  ## Examples

      iex> cast([3, true], :array)
      {:ok, [3, true]}

      iex> cast([1, 2], {:array, :integer})
      {:ok, [1,2]}

      iex> cast([1, "what"], {:array, :integer})
      :error

      iex> cast(1, {:array, :integer})
      :error

      iex> cast(1, :any)
      {:ok, 1}

      iex> cast(true, :boolean)
      {:ok, true}

      iex> cast(1.5, :float)
      {:ok, 1.5}

      iex> cast(2, :integer)
      {:ok, 2}

      iex> cast("example", :string)
      {:ok, "example"}

      iex> cast(:"$undefined", :boolean)
      {:ok, :"$undefined"}

      iex> cast(1234, "not a type")
      :error
  """
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
