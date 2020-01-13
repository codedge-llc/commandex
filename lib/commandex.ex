defmodule Commandex do
  @moduledoc """
  Documentation for Commandex.
  """

  @doc false
  defmacro __using__(_opts) do
    prelude =
      quote do
        # @after_compile Commandex
        Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
        Module.put_attribute(__MODULE__, :struct_fields, {:success, false})
        Module.put_attribute(__MODULE__, :struct_fields, {:error, nil})
        Module.put_attribute(__MODULE__, :struct_fields, {:halted, false})
      end

    postlude =
      quote unquote: false do
        params = for key <- Module.get_attribute(__MODULE__, :params), into: %{}, do: {key, nil}
        data = for key <- Module.get_attribute(__MODULE__, :data), into: %{}, do: {key, nil}

        Module.put_attribute(__MODULE__, :struct_fields, {:params, params})
        Module.put_attribute(__MODULE__, :struct_fields, {:data, data})
        defstruct @struct_fields
        import Commandex
      end

    quote do
      unquote(prelude)
      unquote(postlude)

      def new(opts) do
        Commandex.parse_params(%__MODULE__{}, opts)
      end

      def run(command) do
        pipeline()
        |> Enum.reduce_while(command, fn fun, acc ->
          case acc do
            %{halted: false} -> {:cont, fun.(acc, acc.params, acc.data)}
            _ -> {:halt, acc}
          end
        end)
        |> Commandex.maybe_mark_successful()
      end
    end
  end

  def maybe_mark_successful(%{halted: false} = command), do: %{command | success: true}
  def maybe_mark_successful(command), do: command

  @doc false
  def parse_params(%{params: p} = struct, params) when is_list(params) do
    params = for {key, _} <- p, into: %{}, do: {key, Keyword.get(params, key)}
    %{struct | params: params}
  end

  def parse_params(%{params: p} = struct, %{} = params) do
    params = for {key, _} <- p, into: %{}, do: {key, get_param(params, key)}
    %{struct | params: params}
  end

  defp get_param(params, key) do
    case Map.get(params, key) do
      nil -> Map.get(params, to_string(key))
      val -> val
    end
  end

  def put_data(%{data: data} = command, key, val) do
    %{command | data: Map.put(data, key, val)}
  end

  def put_error(command, error) do
    %{command | error: error}
  end

  def halt(command) do
    %{command | halted: true}
  end
end
