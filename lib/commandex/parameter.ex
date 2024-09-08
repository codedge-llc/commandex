defmodule Commandex.Parameter do
  @moduledoc false

  @base ~w(any boolean float integer string)a

  def check_type!(name, {_outer, inner}) do
    check_type!(name, inner)
  end

  def check_type!(_name, type) when type in @base do
    type
  end

  def check_type!(name, type) do
    raise ArgumentError, "unknown type #{inspect(type)} for param #{inspect(name)}"
  end

  def cast_params(%{__meta__: %{params: schema_params}} = command, params)
      when is_map(params) or is_list(params) do
    schema_params
    |> extract_params(params)
    |> Enum.reduce(command, fn {key, val}, command ->
      {type, _opts} = command.__meta__.params[key]

      case Commandex.Type.cast(val, type) do
        {:ok, :"$undefined"} ->
          command

        {:ok, cast_value} ->
          put_param(command, key, cast_value)

        :error ->
          command
          |> put_param(key, val)
          |> Commandex.put_error(key, :invalid)
      end
    end)
    |> Commandex.maybe_mark_invalid()
  end

  defp extract_params(schema_params, input_params) do
    schema_params
    |> Enum.map(fn {key, {_type, opts}} ->
      default = Keyword.get(opts, :default, :"$undefined")
      {key, get_param(input_params, key, default)}
    end)
    |> Enum.into(%{})
  end

  defp get_param(params, key, default) when is_list(params) do
    Keyword.get(params, key, default)
  end

  defp get_param(params, key, default) when is_map(params) do
    with nil <- Map.get(params, key),
         nil <- Map.get(params, to_string(key)) do
      default
    else
      value -> value
    end
  end

  defp put_param(command, name, value) do
    put_in(command.params[name], value)
  end
end
