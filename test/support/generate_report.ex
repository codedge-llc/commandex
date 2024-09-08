defmodule GenerateReport do
  @moduledoc """
  Example command that generates fake data.

  Used for testing parameter-less commands.
  """

  import Commandex

  command do
    data :total_valid
    data :total_invalid

    pipeline :fetch_data
    pipeline :calculate_results
  end

  def fetch_data(command, _params, _data) do
    # Not real.
    command
  end

  def calculate_results(command, _params, _data) do
    command
    |> put_data(:total_valid, 183_220)
    |> put_data(:total_invalid, 781_215)
  end
end
