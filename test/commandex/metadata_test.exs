defmodule Commandex.MetadataTest do
  use ExUnit.Case

  alias Commandex.Metadata

  describe "inspect/2" do
    test "shows the number of params" do
      assert inspect(%Metadata{}) == "#Commandex.Metadata<0 params>"
      assert inspect(%Metadata{params: %{email: {:string, []}}}) == "#Commandex.Metadata<1 param>"
      assert inspect(%RegisterUser{}.__meta__) == "#Commandex.Metadata<3 params>"
    end

    test "keeps the command struct output short" do
      assert inspect(GenerateReport.new()) =~ "__meta__: #Commandex.Metadata<0 params>"
    end
  end
end
