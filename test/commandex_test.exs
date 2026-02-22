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

    test "sets __meta__ with param schema and pipelines" do
      meta = %RegisterUser{}.__meta__

      assert meta.params.email == {:string, []}
      assert meta.params.password == {:string, []}
      assert meta.params.agree_tos == {:boolean, []}

      assert meta.pipelines == [
               :check_already_registered,
               :verify_tos,
               :create_user,
               :record_auth_attempt
             ]
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

  describe "halt_on_errors/1" do
    test "passes through when no errors" do
      command = RegisterUser.new(%{email: "a@b.com", password: "pass", agree_tos: true})
      result = Commandex.halt_on_errors(command)

      refute result.halted
    end

    test "halts when errors present" do
      command =
        RegisterUser.new()
        |> Commandex.put_error(:email, :invalid)
        |> Commandex.halt_on_errors()

      assert command.halted
      refute command.success
    end

    test "auto-inserted as first pipeline" do
      defmodule HaltOnErrorsExample do
        import Commandex

        command do
          param :value, :integer

          data :result

          pipeline :process
        end

        def process(command, %{value: value}, _data) do
          put_data(command, :result, value * 2)
        end
      end

      halted = HaltOnErrorsExample.run(%{value: "abc"})
      assert halted.halted
      assert halted.errors.value == :invalid

      success = HaltOnErrorsExample.run(%{value: "42"})
      assert success.success
      assert success.data.result == 84
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

  describe "typed param casting" do
    defmodule TypedParams do
      import Commandex

      command do
        param :name, :string
        param :age, :integer
        param :score, :float
        param :active, :boolean
        param :untyped
      end
    end

    test "casts string values to declared types" do
      command =
        TypedParams.new(%{
          "name" => "Alice",
          "age" => "25",
          "score" => "3.14",
          "active" => "true"
        })

      assert command.params.name == "Alice"
      assert command.params.age == 25
      assert command.params.score == 3.14
      assert command.params.active == true
    end

    test "passes through natively-typed values" do
      command = TypedParams.new(%{name: "Bob", age: 30, score: 9.5, active: false})

      assert command.params.name == "Bob"
      assert command.params.age == 30
      assert command.params.score == 9.5
      assert command.params.active == false
    end

    test "puts :invalid error on cast failure" do
      command = TypedParams.new(%{age: "not_a_number", score: "nope"})

      refute command.params.age
      refute command.params.score
      assert command.errors.age == :invalid
      assert command.errors.score == :invalid
    end

    test "untyped params pass through without casting" do
      command = TypedParams.new(%{untyped: {:complex, "value"}})

      assert command.params.untyped == {:complex, "value"}
    end

    test "nil values are not cast failures" do
      command = TypedParams.new(%{age: nil})

      refute command.params.age
      assert command.errors == %{}
    end
  end

  describe "required params" do
    defmodule RequiredParams do
      import Commandex

      command do
        param(:email, :string, required: true)
        param :name, :string
        param(:age, :integer, required: true)
      end
    end

    test "puts :required error when value is nil" do
      command = RequiredParams.new(%{})

      assert command.errors.email == :required
      assert command.errors.age == :required
      refute Map.has_key?(command.errors, :name)
    end

    test "no error when required value is provided" do
      command = RequiredParams.new(%{email: "a@b.com", age: 25})

      assert command.errors == %{}
      assert command.params.email == "a@b.com"
      assert command.params.age == 25
    end

    test ":invalid takes precedence over :required for failed casts" do
      command = RequiredParams.new(%{email: "a@b.com", age: "not_a_number"})

      assert command.errors.age == :required
    end
  end

  describe "error accumulation" do
    defmodule MultiError do
      import Commandex

      command do
        param(:email, :string, required: true)
        param(:age, :integer, required: true)
        param :score, :float
      end
    end

    test "accumulates all errors in a single new/1 call" do
      command = MultiError.new(%{age: "bad", score: "bad"})

      assert command.errors.email == :required
      assert command.errors.age == :required
      assert command.errors.score == :invalid
      assert map_size(command.errors) == 3
    end
  end

  describe "array types" do
    defmodule ArrayParams do
      import Commandex

      command do
        param :tags, {:array, :string}
        param :scores, {:array, :integer}
      end
    end

    test "casts array elements" do
      command = ArrayParams.new(%{tags: ["a", "b"], scores: ["1", "2", "3"]})

      assert command.params.tags == ["a", "b"]
      assert command.params.scores == [1, 2, 3]
    end

    test "puts :invalid if any element fails casting" do
      command = ArrayParams.new(%{scores: ["1", "bad", "3"]})

      refute command.params.scores
      assert command.errors.scores == :invalid
    end

    test "puts :invalid for non-list input" do
      command = ArrayParams.new(%{tags: "not_a_list"})

      refute command.params.tags
      assert command.errors.tags == :invalid
    end

    test "nil array is not a cast failure" do
      command = ArrayParams.new(%{})

      refute command.params.tags
      assert command.errors == %{}
    end
  end

  describe "custom type module" do
    defmodule UpperString do
      @behaviour Commandex.Type

      @type t :: String.t()

      @impl true
      def cast(value) when is_binary(value), do: {:ok, String.upcase(value)}
      def cast(_), do: :error
    end

    defmodule Role do
      @behaviour Commandex.Type

      @type t :: :admin | :user | :guest
      @allowed [:admin, :user, :guest]

      @impl true
      def cast(value) when is_atom(value) and value in @allowed, do: {:ok, value}

      def cast(value) when is_binary(value) do
        atom = String.to_existing_atom(value)
        if atom in @allowed, do: {:ok, atom}, else: :error
      rescue
        ArgumentError -> :error
      end

      def cast(_), do: :error
    end

    defmodule CustomTypeCommand do
      import Commandex

      command do
        param :name, CommandexTest.UpperString
        param(:role, CommandexTest.Role, required: true)
      end
    end

    test "casts using custom type module" do
      command = CustomTypeCommand.new(%{name: "alice", role: :admin})

      assert command.params.name == "ALICE"
      assert command.params.role == :admin
    end

    test "casts string to atom for enum-style type" do
      command = CustomTypeCommand.new(%{role: "guest"})

      assert command.params.role == :guest
    end

    test "rejects values outside the allowed set" do
      command = CustomTypeCommand.new(%{role: "superadmin"})

      refute command.params.role
      assert command.errors.role == :required
    end

    test "rejects non-string non-atom values" do
      command = CustomTypeCommand.new(%{role: 123})

      refute command.params.role
      assert command.errors.role == :required
    end

    test "returns :invalid on custom type cast failure" do
      command = CustomTypeCommand.new(%{name: 123, role: :admin})

      refute command.params.name
      assert command.errors.name == :invalid
    end

    test "nil passes through custom type" do
      command = CustomTypeCommand.new(%{role: :user})

      refute command.params.name
      refute Map.has_key?(command.errors, :name)
    end
  end

  describe "backwards compatibility" do
    defmodule UntypedCommand do
      import Commandex

      command do
        param :name
        param :count, default: 10

        data :result

        pipeline :process
      end

      def process(command, %{name: name, count: count}, _data) do
        Commandex.put_data(command, :result, {name, count})
      end
    end

    test "untyped param works without casting" do
      command = UntypedCommand.new(%{name: "test"})

      assert command.params.name == "test"
      assert command.params.count == 10
    end

    test "untyped param accepts any value" do
      command = UntypedCommand.new(%{name: {:tuple, "value"}, count: [1, 2, 3]})

      assert command.params.name == {:tuple, "value"}
      assert command.params.count == [1, 2, 3]
    end

    test "full pipeline works with untyped params" do
      command = UntypedCommand.run(%{name: "hello"})

      assert command.success
      assert command.data.result == {"hello", 10}
    end

    test "new/0 still works" do
      command = UntypedCommand.new()

      refute command.params.name
      assert command.params.count == 10
    end
  end

  describe "default option with typed params" do
    defmodule DefaultTyped do
      import Commandex

      command do
        param(:score, :float, default: 0.0)
        param(:name, :string, default: "Anonymous")
      end
    end

    test "uses default when param not provided" do
      command = DefaultTyped.new(%{})

      assert command.params.score == 0.0
      assert command.params.name == "Anonymous"
    end

    test "overrides default with provided value" do
      command = DefaultTyped.new(%{score: "9.5", name: "Alice"})

      assert command.params.score == 9.5
      assert command.params.name == "Alice"
    end
  end

  defp assert_params(command) do
    assert command.params.email == @email
    assert command.params.password == @password
    assert command.params.agree_tos == @agree_tos
  end
end
