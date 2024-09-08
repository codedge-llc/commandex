defmodule CommandexTest do
  use ExUnit.Case
  doctest Commandex

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

  describe "param/2 macro" do
    test "raises if duplicate defined" do
      assert_raise ArgumentError, fn ->
        defmodule ExampleParamInvalid do
          import Commandex

          command do
            param :key_1
            param :key_2
            param :key_1
          end
        end
      end
    end
  end

  describe "data/1 macro" do
    test "raises if duplicate defined" do
      assert_raise ArgumentError, fn ->
        defmodule ExampleDataInvalid do
          import Commandex

          command do
            data :key_1
            data :key_2
            data :key_1
          end
        end
      end
    end
  end

  describe "pipeline/1 macro" do
    test "accepts valid pipeline arguments" do
      try do
        defmodule ExamplePipelineValid do
          import Commandex

          command do
            pipeline :example
            pipeline {ExamplePipelineValid, :example}
            pipeline {ExamplePipelineValid, :example_args, ["test"]}
            pipeline &ExamplePipelineValid.example_single/1
            pipeline &ExamplePipelineValid.example/3
          end

          def example(command, _params, _data) do
            command
          end

          def example_single(command) do
            command
          end

          def example_args(command, _params, _data, _custom_value) do
            command
          end
        end

        ExamplePipelineValid.run()
      rescue
        ArgumentError -> flunk("Should not raise.")
      end
    end
  end

  describe "halt/1" do
    test "ignores remaining pipelines" do
      command = RegisterUser.run(%{agree_tos: false})

      refute command.success
      assert command.errors === %{tos: :not_accepted}
    end
  end

  describe "run/0" do
    test "is defined if no params are defined" do
      assert Kernel.function_exported?(GenerateReport, :run, 0)

      command = GenerateReport.run()
      assert command.success
      assert command.data.total_valid > 0
      assert command.data.total_invalid > 0
    end

    test "is not defined if params are defined" do
      refute Kernel.function_exported?(RegisterUser, :run, 0)
    end
  end

  defp assert_params(command) do
    assert command.params.email == @email
    assert command.params.password == @password
    # Don't use refute here because nil fails the test.
    assert command.params.agree_tos == @agree_tos
  end
end
