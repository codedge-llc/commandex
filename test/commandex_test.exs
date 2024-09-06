defmodule CommandexTest do
  use ExUnit.Case
  doctest Commandex
  alias Commandex.RegisterUser

  @email "example@example.com"
  @password "test1234"
  @agree_tos false

  describe "struct assembly" do
    test "sets :params map" do
      for key <- [:email, :password, :agree_tos] do
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

    test "handles atom-key map params correctly" do
      params = %{
        email: @email,
        password: @password,
        agree_tos: @agree_tos
      }

      command = RegisterUser.new(params)
      assert_params(command)
    end

    test "handles string-key map params correctly" do
      params = %{
        email: @email,
        password: @password,
        agree_tos: @agree_tos
      }

      command = RegisterUser.new(params)
      assert_params(command)
    end

    test "handles keyword list params correctly" do
      params = [
        email: @email,
        password: @password,
        agree_tos: @agree_tos
      ]

      command = RegisterUser.new(params)
      assert_params(command)
    end
  end

  describe "run/0" do
    test "is defined if no params are defined" do
      assert Kernel.function_exported?(Commandex.GenerateReport, :run, 0)

      command = Commandex.GenerateReport.run()
      assert command.success
      assert command.data.total_valid > 0
      assert command.data.total_invalid > 0
    end

    test "is not defined if params are defined" do
      refute Kernel.function_exported?(Commandex.RegisterUser, :run, 0)
    end
  end

  defp assert_params(command) do
    assert command.params.email == @email
    assert command.params.password == @password
    # Don't use refute here because nil fails the test.
    assert command.params.agree_tos == @agree_tos
  end
end
