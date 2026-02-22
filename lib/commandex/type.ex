defmodule Commandex.Type do
  @moduledoc """
  Behaviour for custom Commandex types.

  A type module must implement the `cast/1` callback, which converts a raw
  input value into the expected type.

  ## Example

      defmodule MyApp.Types.Color do
        @behaviour Commandex.Type

        @type t :: %{r: integer(), g: integer(), b: integer(), a: float()}

        @impl true
        def cast(%{r: r, g: g, b: b, a: a} = color)
            when is_integer(r) and is_integer(g) and is_integer(b) and is_float(a) do
          {:ok, color}
        end

        def cast(_), do: :error
      end

  The `cast/1` callback should not handle `nil` -- nil is handled centrally
  by `Commandex.Type.cast/2` before delegating to individual type modules.

  ## Compatible with Ecto.Type

  Any module implementing `Ecto.Type`'s `cast/1` callback (returning
  `{:ok, value} | :error`) is compatible as a Commandex type.
  """

  @callback cast(term()) :: {:ok, term()} | :error

  @doc """
  Casts a value to the given type.

  Returns `{:ok, cast_value}` on success or `:error` on failure.
  `nil` always returns `{:ok, nil}` regardless of type.
  """
  @spec cast(term(), atom() | {:array, atom()}) :: {:ok, term()} | :error
  def cast(nil, _type), do: {:ok, nil}
  def cast(value, :any), do: {:ok, value}
  def cast(value, :boolean), do: Commandex.Type.Boolean.cast(value)
  def cast(value, :float), do: Commandex.Type.Float.cast(value)
  def cast(value, :integer), do: Commandex.Type.Integer.cast(value)
  def cast(value, :string), do: Commandex.Type.String.cast(value)
  def cast(value, {:array, type}), do: cast_array(value, type)
  def cast(value, module) when is_atom(module), do: module.cast(value)

  @spec cast_array(term(), atom()) :: {:ok, [term()]} | :error
  defp cast_array(value, type) when is_list(value) do
    value
    |> Enum.reduce_while({:ok, []}, fn element, {:ok, acc} ->
      case cast(element, type) do
        {:ok, cast_value} -> {:cont, {:ok, [cast_value | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      :error -> :error
    end
  end

  defp cast_array(_value, _type), do: :error
end
