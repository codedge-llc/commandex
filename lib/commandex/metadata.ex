defmodule Commandex.Metadata do
  @moduledoc """
  Compile-time metadata of a command.

  Every command struct holds a `Commandex.Metadata` struct in its `__meta__`
  field. `Commandex.command/1` builds it, and `new/1` reads it to cast the
  given parameters.

  ## Attributes

  - `params` - A map of each parameter name to its `{type, opts}` definition.
  """

  defstruct params: %{}

  @type t :: %__MODULE__{params: %{optional(atom()) => {Commandex.Type.t(), Keyword.t()}}}

  defimpl Inspect do
    @spec inspect(Commandex.Metadata.t(), Inspect.Opts.t()) :: String.t()
    def inspect(%{params: params}, _opts) do
      "#Commandex.Metadata<#{count(map_size(params))}>"
    end

    defp count(1), do: "1 param"
    defp count(size), do: "#{size} params"
  end
end
