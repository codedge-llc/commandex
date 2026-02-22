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
        "email" => @email,
        "password" => @password,
        "agree_tos" => @agree_tos
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

      command = ExamplePipelineValid.run()
      assert command.success
    end

    test "raises if invalid argument defined" do
      assert_raise ArgumentError, fn ->
        defmodule ExamplePipelineInvalid do
          import Commandex

          command do
            pipeline 1234
          end
        end
      end
    end
  end

  describe "halt/1" do
    test "sets halted to true and success to false" do
      command = Commandex.halt(RegisterUser.new())

      assert command.halted
      refute command.success
    end
  end

  describe "halt/2" do
    test "sets success to true when option given" do
      command = Commandex.halt(RegisterUser.new(), success: true)

      assert command.halted
      assert command.success
    end

    test "ignores remaining pipelines" do
      command = RegisterUser.run(%{agree_tos: false})

      refute command.success
      assert command.errors === %{tos: :not_accepted}
    end

    test "handles :success option in pipeline" do
      command = RegisterUser.run(%{email: "exists@test.com"})

      assert command.success
      assert command.errors === %{user: :already_exists}
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

  describe "new/1" do
    test "uses defaults when no params given" do
      command = RegisterUser.new()
      assert command.params.email == "test@test.com"
      refute command.params.password
      refute command.params.agree_tos
    end
  end

  describe "put_data/3" do
    test "sets data field on command" do
      command = RegisterUser.new()
      updated = Commandex.put_data(command, :user, %{id: 1})
      assert updated.data.user == %{id: 1}
    end

    test "overwrites existing data field" do
      command = RegisterUser.new()

      updated =
        command
        |> Commandex.put_data(:user, %{id: 1})
        |> Commandex.put_data(:user, %{id: 2})

      assert updated.data.user == %{id: 2}
    end
  end

  describe "put_error/3" do
    test "sets error on command" do
      command = RegisterUser.new()
      updated = Commandex.put_error(command, :email, :invalid)
      assert updated.errors.email == :invalid
    end

    test "overwrites existing error for same key" do
      command = RegisterUser.new()

      updated =
        command
        |> Commandex.put_error(:email, :invalid)
        |> Commandex.put_error(:email, :taken)

      assert updated.errors.email == :taken
    end
  end

  describe "run/1" do
    test "succeeds when all pipelines pass" do
      command = RegisterUser.run(%{email: "new@test.com", password: "pass", agree_tos: true})

      assert command.success
      refute command.halted
      assert command.data.user == %{email: "new@test.com"}
      assert command.data.auth == true
      assert command.errors == %{}
    end

    test "accepts a pre-built struct" do
      command =
        RegisterUser.new(%{email: "new@test.com", password: "pass", agree_tos: true})
        |> RegisterUser.run()

      assert command.success
      assert command.data.user == %{email: "new@test.com"}
    end

    test "halted command does not run subsequent pipelines" do
      command = RegisterUser.run(%{agree_tos: false})

      refute command.success
      assert command.halted
      assert command.errors == %{tos: :not_accepted}
      refute command.data.user
      refute command.data.auth
    end
  end

  defp assert_params(command) do
    assert command.params.email == @email
    assert command.params.password == @password
    assert command.params.agree_tos == @agree_tos
  end
end
