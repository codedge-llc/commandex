defmodule CommandexTest do
  use ExUnit.Case
  doctest Commandex
  alias Commandex.RegisterUser

  describe "struct assembly" do
    test "sets :params map" do
      assert %RegisterUser{}.params == %{email: nil, password: nil}
    end

    test "sets :data map" do
      assert %RegisterUser{}.data == %{user: nil, auth: nil}
    end
  end
end
