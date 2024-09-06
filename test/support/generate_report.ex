defmodule Commandex.GenerateReport do
  @moduledoc """
  Example command that generates fake data.

  Used for testing parameter-less commands.
  """

  import Commandex

  command do
    data :total_valid
    data :total_invalid

    pipeline :calculate_valid
    pipeline :calculate_invalid
  end

  def calculate_valid(command, _params, _data) do
    command
    |> put_data(:total_valid, :rand.uniform(1_000_000))
  end

  def calculate_invalid(command, _params, _data) do
    command
    |> put_data(:total_invalid, :rand.uniform(1_000_000))
  end
end
