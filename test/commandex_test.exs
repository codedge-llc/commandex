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

    test "sets __meta__ with param schema" do
      %Commandex.Metadata{params: params} = %RegisterUser{}.__meta__

      assert params.email == {:string, []}
      assert params.password == {:string, []}
      assert params.agree_tos == {:boolean, []}
    end

    test "sets :pipelines list in the order defined" do
      assert %RegisterUser{}.pipelines == [
               :check_already_registered,
               :verify_tos,
               :create_user,
               :record_auth_attempt
             ]
    end

    test "matches a struct literal that names :pipelines" do
      assert GenerateReport.run() == %GenerateReport{
               data: %{total_invalid: 781_215, total_valid: 183_220},
               errors: %{},
               halted: false,
               params: %{},
               pipelines: [:fetch_data, :calculate_results],
               success: true
             }
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

  describe "param/3 macro" do
    test "raises on an unknown type" do
      assert_raise ArgumentError, "unknown type :intger for param :age", fn ->
        defmodule ExampleUnknownType do
          import Commandex

          command do
            param :age, :intger
          end
        end
      end
    end

    test "raises on an unknown inner type" do
      assert_raise ArgumentError, "unknown type :intger for param :ages", fn ->
        defmodule ExampleUnknownInnerType do
          import Commandex

          command do
            param :ages, {:array, :intger}
          end
        end
      end
    end

    test "raises on an unknown value type of a map" do
      assert_raise ArgumentError, "unknown type :intger for param :counts", fn ->
        defmodule ExampleUnknownMapType do
          import Commandex

          command do
            param :counts, {:map, :intger}
          end
        end
      end
    end

    test "raises on a type that is not an atom" do
      assert_raise ArgumentError, "invalid type {:list, :integer} for param :ages", fn ->
        defmodule ExampleInvalidType do
          import Commandex

          command do
            param :ages, {:list, :integer}
          end
        end
      end
    end

    test "raises on a module that does not implement Commandex.Type" do
      message = "module Enum given as type for param :age does not implement Commandex.Type"

      assert_raise ArgumentError, message, fn ->
        defmodule ExampleNotAType do
          import Commandex

          command do
            param :age, Enum
          end
        end
      end
    end

    test "raises on an unknown option" do
      assert_raise ArgumentError, "invalid option :requried for param/3", fn ->
        defmodule ExampleUnknownOption do
          import Commandex

          command do
            param :age, :integer, requried: true
          end
        end
      end
    end

    test "raises on an unknown option for an untyped param" do
      assert_raise ArgumentError, "invalid option :requried for param/3", fn ->
        defmodule ExampleUnknownUntypedOption do
          import Commandex

          command do
            param :age, requried: true
          end
        end
      end
    end

    test "raises on a default that does not fit the type" do
      message = ~s(value "ten" is invalid for type :integer, cannot set default for param :limit)

      assert_raise ArgumentError, message, fn ->
        defmodule ExampleInvalidDefault do
          import Commandex

          command do
            param :limit, :integer, default: "ten"
          end
        end
      end
    end

    test "casts the default at compile time" do
      defmodule ExampleCastDefault do
        import Commandex

        command do
          param :limit, :integer, default: "10"
          param :ratios, {:array, :float}, default: [1, "2.5"]
        end
      end

      assert struct(ExampleCastDefault).params == %{limit: 10, ratios: [1.0, 2.5]}
    end

    test "casts a date, time, or decimal default at compile time" do
      defmodule ExampleCastStructDefault do
        import Commandex

        command do
          param :starts_on, :date, default: "2026-01-31"
          param :opens_at, :time_usec, default: "09:00"
          param :price, :decimal, default: "9.99"
        end
      end

      assert struct(ExampleCastStructDefault).params == %{
               starts_on: ~D[2026-01-31],
               opens_at: ~T[09:00:00.000000],
               price: Decimal.new("9.99")
             }
    end

    test "keeps an untyped default as given" do
      defmodule ExampleUntypedDefault do
        import Commandex

        command do
          param :limit, default: "10"
        end
      end

      assert struct(ExampleUntypedDefault).params == %{limit: "10"}
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

    test "new/1 halts the command on a cast error" do
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

      assert HaltOnErrorsExample.new(%{value: "abc"}).halted

      halted = HaltOnErrorsExample.run(%{value: "abc"})
      assert halted.halted
      assert halted.errors.value == :invalid
      refute halted.data.result

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

    test "returns an already halted command unchanged" do
      for opts <- [[], [success: true]] do
        command = Commandex.halt(RegisterUser.new(%{agree_tos: true}), opts)

        assert RegisterUser.run(command) == command
      end
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

    test "empty strings are not cast" do
      command = TypedParams.new(%{"name" => "", "age" => "", "score" => "  ", "active" => "\n"})

      assert command.params == %{name: nil, age: nil, score: nil, active: nil, untyped: nil}
      assert command.errors == %{}
      refute command.halted
    end

    test "strings keep their whitespace when not empty" do
      command = TypedParams.new(%{name: "  Alice "})

      assert command.params.name == "  Alice "
    end
  end

  describe "required params" do
    defmodule RequiredParams do
      import Commandex

      command do
        param :email, :string, required: true
        param :name, :string
        param :age, :integer, required: true
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

      assert command.errors.age == :invalid
    end

    test "puts :required error when a typed value is an empty string" do
      command = RequiredParams.new(%{email: " ", age: ""})

      assert command.errors == %{email: :required, age: :required}
    end

    test "halts the command" do
      command = RequiredParams.new(%{})

      assert command.halted
      refute command.success
    end

    test "untyped param accepts an empty string" do
      defmodule RequiredUntyped do
        import Commandex

        command do
          param :token, required: true
        end
      end

      assert RequiredUntyped.new(%{token: ""}).errors == %{}
      assert RequiredUntyped.new(%{}).errors == %{token: :required}
    end
  end

  describe "error accumulation" do
    defmodule MultiError do
      import Commandex

      command do
        param :email, :string, required: true
        param :age, :integer, required: true
        param :score, :float
      end
    end

    test "accumulates all errors in a single new/1 call" do
      command = MultiError.new(%{age: "bad", score: "bad"})

      assert command.errors.email == :required
      assert command.errors.age == :invalid
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

    test "drops empty elements" do
      command = ArrayParams.new(%{tags: ["a", "", "b"], scores: ["1", " "]})

      assert command.params.tags == ["a", "b"]
      assert command.params.scores == [1]
    end
  end

  describe "map types" do
    defmodule MapParams do
      import Commandex

      command do
        param :settings, :map
        param :counts, {:map, :integer}
        param :labels, {:map, :string}
      end
    end

    test "keeps a map as given" do
      command = MapParams.new(%{settings: %{"theme" => "dark", depth: 2}})

      assert command.params.settings == %{"theme" => "dark", depth: 2}
      assert command.errors == %{}
    end

    test "casts the values of a typed map" do
      command = MapParams.new(%{counts: %{"a" => "1", "b" => 2}})

      assert command.params.counts == %{"a" => 1, "b" => 2}
      assert command.errors == %{}
    end

    test "puts :invalid if any value fails casting" do
      command = MapParams.new(%{counts: %{"a" => "1", "b" => "bad"}})

      refute command.params.counts
      assert command.errors == %{counts: :invalid}
    end

    test "puts :invalid for input that is not a map" do
      command = MapParams.new(%{settings: [theme: "dark"], counts: "a=1"})

      assert command.errors == %{settings: :invalid, counts: :invalid}
    end

    test "keeps empty string values" do
      command = MapParams.new(%{labels: %{"a" => "", "b" => "two"}})

      assert command.params.labels == %{"a" => "", "b" => "two"}
    end
  end

  describe "binary type" do
    defmodule BinaryParams do
      import Commandex

      command do
        param :payload, :binary, default: <<1>>
        param :name, :string, default: "none"
      end
    end

    test "uses the default for an empty binary" do
      assert BinaryParams.new(%{payload: ""}).params.payload == <<1>>
    end

    test "does not trim the value" do
      command = BinaryParams.new(%{payload: "  ", name: "  "})

      assert command.params.payload == "  "
      assert command.params.name == "none"
    end

    test "puts :invalid for a value that is not a binary" do
      command = BinaryParams.new(%{payload: 42})

      assert command.params.payload == <<1>>
      assert command.errors == %{payload: :invalid}
    end
  end

  describe "date, time, and decimal types" do
    defmodule BookingParams do
      import Commandex

      command do
        param :starts_on, :date, required: true
        param :opens_at, :time
        param :created_at, :naive_datetime
        param :confirmed_at, :utc_datetime
        param :synced_at, :utc_datetime_usec
        param :price, :decimal
        param :days, {:array, :date}
      end
    end

    test "casts string values" do
      command =
        BookingParams.new(%{
          "starts_on" => "2026-01-31",
          "opens_at" => "09:30",
          "created_at" => "2026-01-31T09:30:15.123",
          "confirmed_at" => "2026-01-31T09:30:15.123+02:00",
          "synced_at" => "2026-01-31T09:30:15Z",
          "price" => "19.90",
          "days" => ["2026-01-31", "2026-02-01"]
        })

      assert command.errors == %{}

      assert command.params == %{
               starts_on: ~D[2026-01-31],
               opens_at: ~T[09:30:00],
               created_at: ~N[2026-01-31 09:30:15],
               confirmed_at: ~U[2026-01-31 07:30:15Z],
               synced_at: ~U[2026-01-31 09:30:15.000000Z],
               price: Decimal.new("19.90"),
               days: [~D[2026-01-31], ~D[2026-02-01]]
             }
    end

    test "keeps values that already have the type" do
      command = BookingParams.new(starts_on: ~D[2026-01-31], price: Decimal.new(5))

      assert command.params.starts_on == ~D[2026-01-31]
      assert command.params.price == Decimal.new(5)
      assert command.errors == %{}
    end

    test "puts :invalid on cast failure" do
      command = BookingParams.new(%{starts_on: "2026-02-30", opens_at: "25:00", price: "NaN"})

      assert command.errors == %{starts_on: :invalid, opens_at: :invalid, price: :invalid}
      assert command.halted
    end

    test "puts :required when the value is an empty string" do
      command = BookingParams.new(%{starts_on: "  "})

      assert command.errors == %{starts_on: :required}
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
        param :role, CommandexTest.Role, required: true
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
      assert command.errors.role == :invalid
    end

    test "rejects non-string non-atom values" do
      command = CustomTypeCommand.new(%{role: 123})

      refute command.params.role
      assert command.errors.role == :invalid
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

  describe "type with options" do
    defmodule APIEnum do
      @behaviour Commandex.Type

      @type t :: atom()

      @impl true
      def init(opts) do
        case Keyword.fetch(opts, :values) do
          {:ok, values} -> Map.merge(from_api(values), Map.new(values, &{&1, &1}))
          :error -> raise ArgumentError, "APIEnum needs the :values option"
        end
      end

      @impl true
      def cast(value, lookup), do: Map.fetch(lookup, value)

      defp from_api(values) do
        Map.new(values, &{String.upcase(Atom.to_string(&1)), &1})
      end
    end

    defmodule EchoOptions do
      @behaviour Commandex.Type

      @type t :: keyword()

      @impl true
      def init(opts), do: opts

      @impl true
      def cast(_value, opts), do: {:ok, opts}
    end

    defmodule EnumCommand do
      import Commandex

      command do
        param :status, CommandexTest.APIEnum, values: [:active, :pending_review], required: true
        param :sort, CommandexTest.APIEnum, values: [:asc, :desc], default: :asc
        param :tags, {:array, CommandexTest.APIEnum}, values: [:new, :sale]
        param :flags, {:map, CommandexTest.APIEnum}, values: [:on, :off]
      end
    end

    test "casts with the params from init/1" do
      command = EnumCommand.new(%{status: "PENDING_REVIEW", sort: "DESC"})

      assert command.params.status == :pending_review
      assert command.params.sort == :desc
      assert command.errors == %{}
    end

    test "accepts a value that is already cast" do
      command = EnumCommand.new(%{status: :active})

      assert command.params.status == :active
    end

    test "each param has its own params" do
      command = EnumCommand.new(%{status: "DESC", sort: "ACTIVE"})

      assert command.errors == %{status: :invalid, sort: :invalid}
    end

    test "puts :invalid when cast/2 fails" do
      command = EnumCommand.new(%{status: "pending_review"})

      refute command.params.status
      assert command.errors == %{status: :invalid}
      assert command.halted
    end

    test "casts the default with the params" do
      command = EnumCommand.new(%{status: "ACTIVE"})

      assert command.params.sort == :asc
    end

    test "passes the options to the inner type of an array" do
      command = EnumCommand.new(%{status: "ACTIVE", tags: ["NEW", "SALE"]})
      assert command.params.tags == [:new, :sale]

      command = EnumCommand.new(%{status: "ACTIVE", tags: ["NEW", "OLD"]})
      assert command.errors == %{tags: :invalid}
    end

    test "passes the options to the value type of a map" do
      command = EnumCommand.new(%{status: "ACTIVE", flags: %{"beta" => "ON"}})
      assert command.params.flags == %{"beta" => :on}

      command = EnumCommand.new(%{status: "ACTIVE", flags: %{"beta" => "MAYBE"}})
      assert command.errors == %{flags: :invalid}
    end

    test "checks required" do
      command = EnumCommand.new(%{})

      assert command.errors == %{status: :required}
    end

    test "does not pass nil to cast/2" do
      command = EnumCommand.new(status: :active, sort: nil)

      refute command.params.sort
      assert command.errors == %{}
    end

    test "stores the type as {:parameterized, {module, params}}" do
      {type, opts} = EnumCommand.new().__meta__.params.sort

      assert type ==
               {:parameterized,
                {APIEnum, %{:asc => :asc, :desc => :desc, "ASC" => :asc, "DESC" => :desc}}}

      assert opts == []
    end

    test "init/1 gets every option from the param line" do
      defmodule EchoCommand do
        import Commandex

        command do
          param :echo, CommandexTest.EchoOptions, level: 1, required: true
        end
      end

      assert EchoCommand.new(%{echo: "value"}).params.echo == [level: 1, required: true]
    end

    test "an error in init/1 shows at compile time" do
      assert_raise ArgumentError, "APIEnum needs the :values option", fn ->
        defmodule ExampleBadTypeOption do
          import Commandex

          command do
            param :status, CommandexTest.APIEnum, vales: [:active]
          end
        end
      end
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

    test "untyped param keeps empty strings" do
      command = UntypedCommand.new(%{name: "", count: ["", " "]})

      assert command.params.name == ""
      assert command.params.count == ["", " "]
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

    test "keyword list keeps an explicit nil over the default" do
      command = UntypedCommand.new(name: "test", count: nil)

      refute command.params.count
    end

    test "keyword list uses the first value of a duplicate key" do
      command = UntypedCommand.new(name: "first", name: "second")

      assert command.params.name == "first"
    end

    test "map uses the string key when the atom key is nil" do
      command = UntypedCommand.new(%{:name => nil, "name" => "test"})

      assert command.params.name == "test"
    end

    test "map uses the default when the atom key is nil" do
      command = UntypedCommand.new(%{count: nil})

      assert command.params.count == 10
    end

    test "map keeps an explicit nil under a string key" do
      command = UntypedCommand.new(%{"count" => nil})

      refute command.params.count
    end

    test "an error put before run/1 does not stop the pipelines" do
      command =
        %{name: "hello"}
        |> UntypedCommand.new()
        |> Commandex.put_error(:warning, :soft)
        |> UntypedCommand.run()

      assert command.success
      assert command.data.result == {"hello", 10}
      assert command.errors == %{warning: :soft}
    end
  end

  describe "default option with typed params" do
    defmodule DefaultTyped do
      import Commandex

      command do
        param :score, :float, default: 0.0
        param :name, :string, default: "Anonymous"
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

    test "uses default when the value is an empty string" do
      command = DefaultTyped.new(%{score: "", name: " "})

      assert command.params.score == 0.0
      assert command.params.name == "Anonymous"
      assert command.errors == %{}
    end

    test "keeps default when the cast fails" do
      command = DefaultTyped.new(%{score: "bad"})

      assert command.params.score == 0.0
      assert command.errors == %{score: :invalid}
      assert command.halted
    end
  end

  defp assert_params(command) do
    assert command.params.email == @email
    assert command.params.password == @password
    assert command.params.agree_tos == @agree_tos
  end
end
