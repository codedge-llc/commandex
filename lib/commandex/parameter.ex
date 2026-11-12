defmodule Commandex.Parameter do
  @moduledoc false

  @valid_opts [:default, :required]

  # Checks a param definition at compile time.
  #
  # Returns the type and the options. The default in the options is cast
  # to the type, so `new/1` does not cast it again.
  @spec define!(atom(), term(), Keyword.t()) :: {Commandex.Type.t(), Keyword.t()}
  def define!(name, type, opts) do
    type = check_type!(name, type, opts)
    check_opts!(type, opts)

    {type, cast_default!(name, type, opts)}
  end

  # A module with options becomes `{:parameterized, {module, params}}`.
  # Its `init/1` runs here, with the options from the param line.
  @spec check_type!(atom(), term(), Keyword.t()) :: Commandex.Type.t()
  defp check_type!(name, {composite, inner}, opts) when composite in [:array, :map] do
    {composite, check_type!(name, inner, opts)}
  end

  defp check_type!(name, type, _opts) when not is_atom(type) do
    raise ArgumentError, "invalid type #{inspect(type)} for param #{inspect(name)}"
  end

  defp check_type!(name, type, opts) do
    cond do
      type == :decimal and not Code.ensure_loaded?(Decimal) ->
        raise ArgumentError,
              "type :decimal for param #{inspect(name)} needs the :decimal package. " <>
                ~s(Add {:decimal, "~> 3.0"} to the deps in mix.exs)

      Commandex.Type.base?(type) ->
        type

      Code.ensure_compiled(type) != {:module, type} ->
        raise ArgumentError, "unknown type #{inspect(type)} for param #{inspect(name)}"

      function_exported?(type, :init, 1) and function_exported?(type, :cast, 2) ->
        {:parameterized, {type, type.init(opts)}}

      function_exported?(type, :cast, 1) ->
        type

      true ->
        raise ArgumentError,
              "module #{inspect(type)} given as type for param #{inspect(name)} " <>
                "does not implement Commandex.Type"
    end
  end

  # A type with options checks its own options in `init/1`.
  @spec check_opts!(Commandex.Type.t(), Keyword.t()) :: :ok
  defp check_opts!({:parameterized, _type}, _opts), do: :ok
  defp check_opts!({_composite, type}, opts), do: check_opts!(type, opts)

  defp check_opts!(_type, opts) do
    case Enum.find(opts, fn {key, _value} -> key not in @valid_opts end) do
      {key, _value} -> raise ArgumentError, "invalid option #{inspect(key)} for param/3"
      nil -> :ok
    end
  end

  @spec cast_default!(atom(), Commandex.Type.t(), Keyword.t()) :: Keyword.t()
  defp cast_default!(name, type, opts) do
    default = Keyword.get(opts, :default)

    case Commandex.Type.cast(type, default) do
      {:ok, nil} ->
        opts

      {:ok, cast_default} ->
        Keyword.put(opts, :default, cast_default)

      :error ->
        raise ArgumentError,
              "value #{inspect(default)} is invalid for type #{inspect(type)}, " <>
                "cannot set default for param #{inspect(name)}"
    end
  end

  @spec cast_params(struct(), map() | Keyword.t()) :: struct()
  def cast_params(%{__meta__: %{params: schema}} = command, input)
      when is_list(input) or is_map(input) do
    Enum.reduce(schema, command, fn {key, {type, opts}}, acc ->
      acc
      |> put_param(key, type, fetch_param(input, key))
      |> check_required(key, opts)
    end)
  end

  # The lookup rules are the same as in 0.5.2.
  #
  # Keyword input uses the first value for a key and keeps an explicit nil.
  # Map input tries the atom key first. If that value is nil, it tries the
  # string key. A param that is not found keeps its default.
  @spec fetch_param(map() | Keyword.t(), atom()) :: {:ok, term()} | :error
  defp fetch_param(input, key) when is_list(input) do
    Keyword.fetch(input, key)
  end

  defp fetch_param(input, key) do
    case Map.get(input, key) do
      nil -> Map.fetch(input, Atom.to_string(key))
      value -> {:ok, value}
    end
  end

  # The struct starts with every default in place. A param keeps its default
  # if the value is not found, is empty, or fails the cast.
  @spec put_param(struct(), atom(), Commandex.Type.t(), {:ok, term()} | :error) :: struct()
  defp put_param(command, _key, _type, :error), do: command

  defp put_param(%{params: params} = command, key, type, {:ok, value}) do
    case cast_value(type, value) do
      {:ok, cast_value} -> %{command | params: Map.put(params, key, cast_value)}
      :empty -> command
      :error -> Commandex.put_error(command, key, :invalid)
    end
  end

  @spec cast_value(Commandex.Type.t(), term()) :: {:ok, term()} | :empty | :error
  defp cast_value(type, value) do
    case reject_empty(type, value) do
      {:ok, value} -> Commandex.Type.cast(type, value)
      :empty -> :empty
    end
  end

  # The rules for empty values are the same as in `Ecto.Changeset.cast/4`.
  #
  # A string that is empty after a leading trim is an empty value. An array
  # drops its empty elements. An `:any` type keeps every value as given, and
  # a `:binary` type is not trimmed.
  @spec reject_empty(Commandex.Type.t(), term()) :: {:ok, term()} | :empty
  defp reject_empty({:array, type}, value) when is_list(value) do
    {:ok, for(element <- value, {:ok, element} <- [reject_empty(type, element)], do: element)}
  end

  defp reject_empty(type, value) do
    if empty?(type, value) do
      :empty
    else
      {:ok, value}
    end
  end

  @spec empty?(Commandex.Type.t(), term()) :: boolean()
  defp empty?(:any, _value), do: false
  defp empty?(:binary, value), do: value == ""
  defp empty?(_type, value) when is_binary(value), do: String.trim_leading(value) == ""
  defp empty?(_type, _value), do: false

  @spec check_required(struct(), atom(), Keyword.t()) :: struct()
  defp check_required(command, key, opts) do
    if Keyword.get(opts, :required, false) and missing?(command, key) do
      Commandex.put_error(command, key, :required)
    else
      command
    end
  end

  # A param is missing if its value is nil. A param with an `:invalid` error
  # is not missing, so `:invalid` wins over `:required`.
  @spec missing?(struct(), atom()) :: boolean()
  defp missing?(%{errors: errors, params: params}, key) do
    is_nil(Map.fetch!(params, key)) and not Map.has_key?(errors, key)
  end
end
