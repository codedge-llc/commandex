defmodule CommandexTest do
  use ExUnit.Case
  doctest Commandex
  alias Commandex.RegisterUser

  describe "struct assembly" do
    test "sets :params map" do
      for key <- [:email, :password] do
        assert Map.has_key?(%RegisterUser{}.params, key)
      end
    end

    test "sets param default if specified" do
      assert %RegisterUser{}.params.email == "test@test.com"
    end

    test "sets :data map" do
      for key <- [:user, :auth] do
        assert Map.has_key?(%RegisterUser{}.data, key)
      end
    end
  end
end
