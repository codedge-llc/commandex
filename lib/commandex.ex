defmodule Commandex do
  @moduledoc """
  Documentation for Commandex.
  """

  @doc false
  defmacro command(do: block) do
    prelude =
      quote do
        Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
        Module.register_attribute(__MODULE__, :params, accumulate: true)
        Module.register_attribute(__MODULE__, :data, accumulate: true)
        Module.register_attribute(__MODULE__, :pipelines, accumulate: true)

        Module.put_attribute(__MODULE__, :struct_fields, {:success, false})
        Module.put_attribute(__MODULE__, :struct_fields, {:error, nil})
        Module.put_attribute(__MODULE__, :struct_fields, {:halted, false})

        try do
          import Commandex
          unquote(block)
        after
          :ok
        end
      end

    postlude =
      quote unquote: false do
        params = for pair <- Module.get_attribute(__MODULE__, :params), into: %{}, do: pair
        data = for pair <- Module.get_attribute(__MODULE__, :data), into: %{}, do: pair
        pipelines = Module.get_attribute(__MODULE__, :pipelines)

        Module.put_attribute(__MODULE__, :struct_fields, {:params, params})
        Module.put_attribute(__MODULE__, :struct_fields, {:data, data})
        Module.put_attribute(__MODULE__, :struct_fields, {:pipelines, pipelines})
        defstruct @struct_fields

        @doc """
        Creates a new #{__MODULE__} struct from given params.
        """
        def new(opts) do
          Commandex.parse_params(%__MODULE__{}, opts)
        end

        def run(%unquote(__MODULE__){pipelines: pipelines} = command) do
          pipelines
          |> Enum.reduce_while(command, fn fun, acc ->
            case acc do
              %{halted: false} -> {:cont, Commandex.apply_fun(command, fun)}
              _ -> {:halt, acc}
            end
          end)
          |> Commandex.maybe_mark_successful()
        end

        def run(params) do
          params
          |> new()
          |> run()
        end
      end

    quote do
      unquote(prelude)
      unquote(postlude)
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

  defmacro param(name, type \\ :string, opts \\ []) do
    quote do
      Commandex.__param__(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  defmacro data(name, type \\ :string, opts \\ []) do
    quote do
      Commandex.__data__(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  defmacro pipeline(name) do
    quote do
      Commandex.__pipeline__(__MODULE__, unquote(name))
    end
  end

  def __param__(mod, name, _type, _opts) do
    params = Module.get_attribute(mod, :params)

    if List.keyfind(params, name, 0) do
      raise ArgumentError, "param #{inspect(name)} is already set on command"
    end

    Module.put_attribute(mod, :params, {name, nil})
  end

  def __data__(mod, name, _type, _opts) do
    data = Module.get_attribute(mod, :data)

    if List.keyfind(data, name, 0) do
      raise ArgumentError, "data #{inspect(name)} is already set on command"
    end

    Module.put_attribute(mod, :data, {name, nil})
  end

  def __pipeline__(mod, name) do
    Module.put_attribute(mod, :pipelines, name)
  end

  def apply_fun(%mod{params: params, data: data} = command, name) when is_atom(name) do
    :erlang.apply(mod, name, [command, params, data])
  end

  def apply_fun(%{params: params, data: data} = command, fun) when is_function(fun) do
    fun.(command, params, data)
  end

  def apply_fun(%{params: params, data: data} = command, {m, f}) do
    :erlang.apply(m, f, [command, params, data])
  end

  def apply_fun(%{params: params, data: data} = command, {m, f, a}) do
    :erlang.apply(m, f, [command, params, data] ++ a)
  end
end
