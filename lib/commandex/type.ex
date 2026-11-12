defmodule Commandex.Type do
  @moduledoc """
  Behaviour for custom Commandex types.

  A type module implements the `cast/1` callback, which converts a raw
  input value into the value that the command uses.

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

  Use the module as the type of a param:

      param :color, MyApp.Types.Color

  ## The `t()` type

  A type module must define a `t()` type. The typespec of the command
  struct refers to it. The `:color` param above has the spec
  `MyApp.Types.Color.t() | nil`.

  If the module does not define `t()`, the command still compiles and
  runs. Dialyzer then reports an unknown type.

  ## Types with options

  A type can take options from the `param` line. A type with options
  implements `init/1` and `cast/2`, and does not implement `cast/1`.

  `init/1` runs at compile time. It gets the options from the `param` line
  and returns the params of the type. `cast/2` gets the raw input value and
  those params.

  This example is an enum type for an API that sends `"PENDING_REVIEW"`
  when the command needs `:pending_review`:

      defmodule MyApp.Types.Enum do
        @behaviour Commandex.Type

        @type t :: atom()

        @impl true
        def init(opts) do
          values = Keyword.fetch!(opts, :values)
          from_api = Map.new(values, &{String.upcase(Atom.to_string(&1)), &1})
          from_atom = Map.new(values, &{&1, &1})

          Map.merge(from_api, from_atom)
        end

        @impl true
        def cast(value, lookup), do: Map.fetch(lookup, value)
      end

  Each param gives its own options:

      param :status, MyApp.Types.Enum, values: [:active, :pending_review]
      param :sort, MyApp.Types.Enum, values: [:asc, :desc], default: :asc

  Obey these rules when you write a type with options:

  - `init/1` gets every option from the `param` line. This includes
    `:default` and `:required`.
  - Raise an error in `init/1` if an option is not valid. The error then
    shows at compile time.
  - Return plain data from `init/1`, such as a map or a list. The command
    struct stores the value, so it cannot contain an anonymous function.

  ## Nil values

  A type module does not get a `nil` value. `Commandex.Type.cast/2` returns
  `{:ok, nil}` for `nil` before it calls the module.
  """

  @typedoc """
  A parameter type.

  A type is a built-in atom, an `{:array, type}` or `{:map, type}` tuple,
  or a module that implements this behaviour. A module with options is
  stored as `{:parameterized, {module, params}}`.
  """
  @type t ::
          :any
          | :binary
          | :boolean
          | :date
          | :decimal
          | :float
          | :integer
          | :map
          | :naive_datetime
          | :naive_datetime_usec
          | :string
          | :time
          | :time_usec
          | :utc_datetime
          | :utc_datetime_usec
          | {:array, t()}
          | {:map, t()}
          | {:parameterized, {module(), params :: term()}}
          | module()

  @doc """
  Casts a raw input value.

  Return `{:ok, value}` if the cast succeeds and `:error` if it fails.
  `{:error, keyword}` is also a failure.
  """
  @callback cast(value :: term()) :: {:ok, term()} | :error | {:error, keyword()}

  @doc """
  Casts a raw input value with the params from `c:init/1`.

  The return values are the same as for `c:cast/1`.
  """
  @callback cast(value :: term(), params :: term()) ::
              {:ok, term()} | :error | {:error, keyword()}

  @doc """
  Converts the options from the `param` line into the params of the type.

  This callback runs at compile time.
  """
  @callback init(opts :: keyword()) :: term()

  @optional_callbacks cast: 1, cast: 2, init: 1

  @base ~w(
    any binary boolean date decimal float integer map
    naive_datetime naive_datetime_usec string
    time time_usec utc_datetime utc_datetime_usec
  )a

  @doc false
  @spec base?(term()) :: boolean()
  def base?(type), do: type in @base

  @doc """
  Casts a value to the given type.

  Returns `{:ok, cast_value}` if the cast succeeds and `:error` if it fails.
  `nil` always returns `{:ok, nil}`, for every type.

  ## Examples

      iex> Commandex.Type.cast(:integer, "42")
      {:ok, 42}

      iex> Commandex.Type.cast(:integer, 4.2)
      :error

      iex> Commandex.Type.cast({:array, :boolean}, ["true", "0"])
      {:ok, [true, false]}

      iex> Commandex.Type.cast(:string, nil)
      {:ok, nil}
  """
  @spec cast(t(), term()) :: {:ok, term()} | :error
  def cast(_type, nil), do: {:ok, nil}
  def cast(:any, value), do: {:ok, value}
  def cast(:binary, value), do: Commandex.Type.String.cast(value)
  def cast(:boolean, value), do: Commandex.Type.Boolean.cast(value)
  def cast(:date, value), do: Commandex.Type.Date.cast(value)
  def cast(:decimal, value), do: Commandex.Type.Decimal.cast(value)
  def cast(:float, value), do: Commandex.Type.Float.cast(value)
  def cast(:integer, value), do: Commandex.Type.Integer.cast(value)
  def cast(:map, value), do: Commandex.Type.Map.cast(value)
  def cast(:naive_datetime, value), do: drop_usec(Commandex.Type.NaiveDateTime.cast(value))
  def cast(:naive_datetime_usec, value), do: pad_usec(Commandex.Type.NaiveDateTime.cast(value))
  def cast(:string, value), do: Commandex.Type.String.cast(value)
  def cast(:time, value), do: drop_usec(Commandex.Type.Time.cast(value))
  def cast(:time_usec, value), do: pad_usec(Commandex.Type.Time.cast(value))
  def cast(:utc_datetime, value), do: drop_usec(Commandex.Type.UTCDateTime.cast(value))
  def cast(:utc_datetime_usec, value), do: pad_usec(Commandex.Type.UTCDateTime.cast(value))
  def cast({:array, type}, value), do: cast_array(type, value)
  def cast({:map, type}, value), do: cast_map(type, value)
  def cast({:parameterized, {module, params}}, value), do: result(module.cast(value, params))
  def cast(module, value) when is_atom(module), do: result(module.cast(value))

  @doc false
  @spec to_spec(t()) :: Macro.t()
  def to_spec(:any), do: quote(do: term())
  def to_spec(type), do: quote(do: unquote(spec(type)) | nil)

  # The spec of a value that is not `nil`. `to_spec/1` adds `nil` one time,
  # at the top level.
  @spec spec(t()) :: Macro.t()
  defp spec(:any), do: quote(do: term())
  defp spec(:binary), do: quote(do: binary())
  defp spec(:boolean), do: quote(do: boolean())
  defp spec(:date), do: quote(do: Date.t())
  defp spec(:decimal), do: quote(do: Decimal.t())
  defp spec(:float), do: quote(do: float())
  defp spec(:integer), do: quote(do: integer())
  defp spec(:map), do: quote(do: map())
  defp spec(:naive_datetime), do: quote(do: NaiveDateTime.t())
  defp spec(:naive_datetime_usec), do: quote(do: NaiveDateTime.t())
  defp spec(:string), do: quote(do: String.t())
  defp spec(:time), do: quote(do: Time.t())
  defp spec(:time_usec), do: quote(do: Time.t())
  defp spec(:utc_datetime), do: quote(do: DateTime.t())
  defp spec(:utc_datetime_usec), do: quote(do: DateTime.t())
  defp spec({:array, type}), do: quote(do: [unquote(spec(type))])
  defp spec({:map, type}), do: quote(do: %{optional(term()) => unquote(spec(type))})
  defp spec({:parameterized, {module, _params}}), do: spec(module)
  defp spec(module) when is_atom(module), do: quote(do: unquote(module).t())

  # A custom type can return `{:error, keyword}`. Commandex has no use for
  # the keyword, so the result is `:error`.
  @spec result({:ok, term()} | :error | {:error, keyword()}) :: {:ok, term()} | :error
  defp result({:ok, _cast_value} = ok), do: ok
  defp result(:error), do: :error
  defp result({:error, reason}) when is_list(reason), do: :error

  @spec cast_array(t(), term()) :: {:ok, [term()]} | :error
  defp cast_array(type, value) when is_list(value) do
    value
    |> Enum.reduce_while({:ok, []}, fn element, {:ok, acc} ->
      case cast(type, element) do
        {:ok, cast_value} -> {:cont, {:ok, [cast_value | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      :error -> :error
    end
  end

  defp cast_array(_type, _value), do: :error

  @spec cast_map(t(), term()) :: {:ok, map()} | :error
  defp cast_map(type, value) when is_map(value) do
    value
    |> Map.to_list()
    |> Enum.reduce_while({:ok, %{}}, fn {key, element}, {:ok, acc} ->
      case cast(type, element) do
        {:ok, cast_value} -> {:cont, {:ok, Map.put(acc, key, cast_value)}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp cast_map(_type, _value), do: :error

  # A type without `_usec` in its name drops the microseconds.
  @spec drop_usec({:ok, struct()} | :error) :: {:ok, struct()} | :error
  defp drop_usec({:ok, value}), do: {:ok, %{value | microsecond: {0, 0}}}
  defp drop_usec(:error), do: :error

  # A type with `_usec` in its name always has a precision of 6 digits.
  @spec pad_usec({:ok, struct()} | :error) :: {:ok, struct()} | :error
  defp pad_usec({:ok, %{microsecond: {usec, _precision}} = value}) do
    {:ok, %{value | microsecond: {usec, 6}}}
  end

  defp pad_usec(:error), do: :error
end
