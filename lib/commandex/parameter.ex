defmodule Commandex.Parameter do
  @moduledoc false

  @spec cast_params(struct(), map() | Keyword.t()) :: struct()
  def cast_params(command, input) when is_list(input) do
    cast_params(command, Enum.into(input, %{}))
  end

  def cast_params(%{__meta__: %{params: schema}, params: defaults} = command, %{} = input) do
    Enum.reduce(schema, command, fn {key, {type, opts}}, acc ->
      default = Map.get(defaults, key)
      raw = get_param(input, key, default)

      acc
      |> cast_value(key, raw, type)
      |> check_required(key, opts)
    end)
  end

  @spec get_param(map(), atom(), term()) :: term()
  defp get_param(params, key, default) do
    case Map.get(params, key) do
      nil -> Map.get(params, to_string(key), default)
      val -> val
    end
  end

  @spec cast_value(struct(), atom(), term(), atom() | {:array, atom()}) :: struct()
  defp cast_value(command, key, raw, type) do
    case Commandex.Type.cast(raw, type) do
      {:ok, cast_value} ->
        put_in(command, [Access.key!(:params), Access.key!(key)], cast_value)

      :error ->
        command
        |> put_in([Access.key!(:params), Access.key!(key)], nil)
        |> Commandex.put_error(key, :invalid)
    end
  end

  @spec check_required(struct(), atom(), Keyword.t()) :: struct()
  defp check_required(command, key, opts) do
    if Keyword.get(opts, :required, false) and not Map.has_key?(command.errors, key) do
      case get_in(command, [Access.key!(:params), Access.key!(key)]) do
        nil -> Commandex.put_error(command, key, :required)
        _ -> command
      end
    else
      command
    end
  end
end
