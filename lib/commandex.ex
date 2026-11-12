defmodule Commandex do
  @moduledoc """
  Defines a command struct.

  Commandex is a loose implementation of the command pattern, making it easy
  to wrap parameters, data, and errors into a well-defined struct.

  ## Example

  A fully implemented command module might look like this:

      defmodule RegisterUser do
        import Commandex

        command do
          param :email, :string, required: true
          param :password, :string

          data :password_hash
          data :user

          pipeline :hash_password
          pipeline :create_user
          pipeline :send_welcome_email
        end

        def hash_password(command, %{password: nil} = _params, _data) do
          command
          |> put_error(:password, :not_given)
          |> halt()
        end

        def hash_password(command, %{password: password} = _params, _data) do
          put_data(command, :password_hash, Base.encode64(password))
        end

        def create_user(command, %{email: email} = _params, %{password_hash: phash} = _data) do
          %User{}
          |> User.changeset(%{email: email, password_hash: phash})
          |> Repo.insert()
          |> case do
            {:ok, user} -> put_data(command, :user, user)
            {:error, changeset} -> command |> put_error(:repo, changeset) |> halt()
          end
        end

        def send_welcome_email(command, _params, %{user: user}) do
          Mailer.send_welcome_email(user)
          command
        end
      end

  The `command/1` macro will define a struct that looks like:

      %RegisterUser{
        __meta__: #Commandex.Metadata<2 params>,
        success: false,
        halted: false,
        errors: %{},
        params: %{email: nil, password: nil},
        data: %{password_hash: nil, user: nil},
        pipelines: [:hash_password, :create_user, :send_welcome_email]
      }

  As well as two functions:

      &RegisterUser.new/1
      &RegisterUser.run/1

  `&new/1` parses and casts parameters into a new struct. These can be either a
  keyword list or map with atom/string keys. If a parameter has a type declared,
  the value will be cast to that type. If the cast fails, the parameter keeps its
  default and an `:invalid` error is added. If a parameter is marked as `required: true`
  and its value is `nil` after casting, a `:required` error is added. A command with
  either error is halted, so `&run/1` does not run any pipelines.

  `&run/1` takes a command struct and runs it through the pipeline functions defined
  in the command. **Functions are executed in the order in which they are defined**.
  If a command passes through all pipelines without calling `halt/1`, `:success`
  will be set to `true`. Otherwise, subsequent pipelines after the `halt/1` will
  be ignored and `:success` will be set to `false`.

      %{email: "example@example.com", password: "asdf1234"}
      |> RegisterUser.new()
      |> RegisterUser.run()
      |> case do
        %{success: true, data: %{user: user}} ->
          # Success! We've got a user now

        %{success: false, errors: %{password: :not_given}} ->
          # Respond with a 400 or something

        %{success: false, errors: _errors} ->
          # I'm a lazy programmer that writes catch-all error handling
      end

  ## Parameter-less Commands

  If a command does not have any parameters defined, a `run/0` will be generated
  automatically. Useful for diagnostic jobs and internal tasks.

      iex> command = GenerateReport.run()
      iex> command.success
      true
      iex> command.data.total_valid
      183220
      iex> command.data.total_invalid
      781215

  ## Typed Parameters

  A parameter can declare a type. `&new/1` casts the value to that type:

      param :age, :integer
      param :email, :string, required: true
      param :score, :float, default: 0.0
      param :starts_on, :date
      param :tags, {:array, :string}
      param :counts, {:map, :integer}

  A parameter without a type has the `:any` type. `&new/1` does not cast
  it and keeps the value as given.

  ### Built-in types

  | Type                   | Value after the cast                     |
  | ---------------------- | ---------------------------------------- |
  | `:any`                 | The value as given                       |
  | `:binary`              | A binary                                 |
  | `:boolean`             | `true` or `false`                        |
  | `:date`                | A `Date`                                 |
  | `:decimal`             | A `Decimal`                              |
  | `:float`               | A float                                  |
  | `:integer`             | An integer                               |
  | `:map`                 | A map                                    |
  | `:naive_datetime`      | A `NaiveDateTime` without microseconds   |
  | `:naive_datetime_usec` | A `NaiveDateTime` with microseconds      |
  | `:string`              | A string                                 |
  | `:time`                | A `Time` without microseconds            |
  | `:time_usec`           | A `Time` with microseconds               |
  | `:utc_datetime`        | A `DateTime` in UTC without microseconds |
  | `:utc_datetime_usec`   | A `DateTime` in UTC with microseconds    |
  | `{:array, type}`       | A list of values of the inner type       |
  | `{:map, type}`         | A map with values of the inner type      |

  The built-in types follow the cast rules of Ecto. For example, `:integer`
  accepts `42` and `"42"`, and does not accept `42.0`.

  The `:decimal` type needs the optional `:decimal` package, version 3.0
  or later.

  ### Custom types

  A module that implements the `Commandex.Type` behaviour can be the type of
  a parameter. A type can also take options from the `param` line:

      param :color, MyApp.Types.Color
      param :status, MyApp.Types.Enum, values: [:active, :pending_review]

  See `Commandex.Type` for how to write each kind of type.

  ### Empty values

  For a typed parameter, a string that is empty or has only whitespace is
  an empty value. `&new/1` does not cast an empty value, and the parameter
  keeps its default. An array drops its empty elements. A `:binary`
  parameter is empty only for `""`.

  ### Errors

  If a cast fails, the parameter keeps its default and gets an `:invalid`
  error. If a parameter with `required: true` is `nil` after the cast, it
  gets a `:required` error. `&new/1` halts a command that has an error.

      command = RegisterUser.new(%{password: 42})

      command.errors
      #=> %{email: :required, password: :invalid}

      command.halted
      #=> true
  """

  @typedoc """
  Command pipeline stage.

  A pipeline function can be defined multiple ways:

  - `pipeline :do_work` - Name of a function inside the command's module, arity three.
  - `pipeline {YourModule, :do_work}` - Arity three.
  - `pipeline {YourModule, :do_work, [:additional, "args"]}` - Arity three plus the
    number of additional args given.
  - `pipeline &YourModule.do_work/1` - Or any anonymous function of arity one.
  - `pipeline &YourModule.do_work/3` - Or any anonymous function of arity three.
  """
  @type pipeline ::
          atom()
          | {module(), atom()}
          | {module(), atom(), [any()]}
          | (command :: struct() -> command :: struct())
          | (command :: struct(), params :: map(), data :: map() -> command :: struct())

  @typedoc """
  Command struct.

  ## Attributes

  - `__meta__` - Compile-time metadata with the parameter types. See `Commandex.Metadata`.
  - `data` - Data generated during the pipeline, defined by `Commandex.data/1`.
  - `errors` - Errors generated during the pipeline with `Commandex.put_error/3`
  - `halted` - Whether or not the pipeline was halted.
  - `params` - Parameters given to the command, defined by `Commandex.param/1`.
  - `pipelines` - A list of pipeline functions to execute, defined by `Commandex.pipeline/1`.
  - `success` - Whether or not the command was successful. This is only set to
    `true` if the command was not halted after running all of the pipelines.
  """
  @type command :: %{
          __struct__: atom(),
          __meta__: Commandex.Metadata.t(),
          data: map(),
          errors: map(),
          halted: boolean(),
          params: map(),
          pipelines: [pipeline()],
          success: boolean()
        }

  @doc """
  Defines a command struct with params, data, and pipelines.
  """
  @spec command(do: any()) :: no_return()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro command(do: block) do
    prelude =
      quote do
        for name <- [:struct_fields, :params, :data, :pipelines] do
          Module.register_attribute(__MODULE__, name, accumulate: true)
        end

        for field <- [{:success, false}, {:errors, %{}}, {:halted, false}] do
          Module.put_attribute(__MODULE__, :struct_fields, field)
        end

        try do
          import Commandex
          unquote(block)
        after
          :ok
        end
      end

    postlude =
      quote unquote: false do
        raw_params = Module.get_attribute(__MODULE__, :params)

        param_defaults =
          for {name, {_type, opts}} <- raw_params, into: %{} do
            {name, Keyword.get(opts, :default)}
          end

        param_schema =
          for {name, {type, opts}} <- raw_params, into: %{} do
            {name, {type, Keyword.take(opts, [:required])}}
          end

        data = for pair <- Module.get_attribute(__MODULE__, :data), into: %{}, do: pair

        pipelines = __MODULE__ |> Module.get_attribute(:pipelines) |> Enum.reverse()

        meta = %Commandex.Metadata{params: param_schema}

        Module.put_attribute(__MODULE__, :struct_fields, {:__meta__, meta})
        Module.put_attribute(__MODULE__, :struct_fields, {:params, param_defaults})
        Module.put_attribute(__MODULE__, :struct_fields, {:data, data})
        Module.put_attribute(__MODULE__, :struct_fields, {:pipelines, pipelines})
        defstruct @struct_fields

        param_type_specs =
          for {name, {type, _opts}} <- raw_params do
            {name, Commandex.Type.to_spec(type)}
          end

        data_type_specs =
          for {name, _} <- Module.get_attribute(__MODULE__, :data) do
            {name, quote(do: term())}
          end

        @typedoc """
        Command struct.

        ## Attributes

        - `__meta__` - Compile-time metadata with the parameter types. See `Commandex.Metadata`.
        - `data` - Data generated during the pipeline, defined by `Commandex.data/1`.
        - `errors` - Errors generated during the pipeline with `Commandex.put_error/3`
        - `halted` - Whether or not the pipeline was halted.
        - `params` - Parameters given to the command, defined by `Commandex.param/1`.
        - `pipelines` - A list of pipeline functions to execute, defined by `Commandex.pipeline/1`.
        - `success` - Whether or not the command was successful. This is only set to
          `true` if the command was not halted after running all of the pipelines.
        """
        @type t :: %__MODULE__{
                __meta__: Commandex.Metadata.t(),
                data: %{unquote_splicing(data_type_specs)},
                errors: map(),
                halted: boolean(),
                params: %{unquote_splicing(param_type_specs)},
                pipelines: [Commandex.pipeline()],
                success: boolean()
              }

        @doc """
        Creates a new struct from given parameters.
        """
        @spec new(map() | Keyword.t()) :: t()
        def new(opts \\ []) do
          %__MODULE__{}
          |> Commandex.Parameter.cast_params(opts)
          |> Commandex.halt_on_errors()
        end

        if Enum.empty?(param_defaults) do
          @doc """
          Runs given pipelines in order and returns command struct.
          """
          @spec run() :: t()
          def run do
            new() |> run()
          end
        end

        @doc """
        Runs given pipelines in order and returns command struct.

        `run/1` can either take parameters that would be passed to `new/1`
        or the command struct itself.
        """
        @spec run(map() | Keyword.t() | t()) :: t()
        def run(%unquote(__MODULE__){pipelines: pipelines} = command) do
          Commandex.run_pipelines(command, pipelines)
        end

        def run(params) do
          params |> new() |> run()
        end
      end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  @doc """
  Defines a command parameter field.

  Parameters are supplied at struct creation, before any pipelines are run.

  ## Untyped

      command do
        param :email
        param :name, default: "Anonymous"
      end

  ## Typed

  `new/1` casts a typed parameter to its type:

      command do
        param :email, :string, required: true
        param :age, :integer
        param :score, :float, default: 0.0
        param :tags, {:array, :string}
        param :color, MyApp.Types.Color
        param :status, MyApp.Types.Enum, values: [:active, :pending_review]
      end

  The type is a built-in type or a module that implements `Commandex.Type`.
  See the "Typed Parameters" section of the `Commandex` module for the list
  of built-in types.

  ## Options

  - `:default` - Default value if not provided. Defaults to `nil`. A typed
    parameter casts its default at compile time.
  - `:required` - If `true`, adds a `:required` error when the value is `nil`
    after casting.

  A type with options also gets every option on the line. Each other
  parameter raises an `ArgumentError` at compile time for an option that
  is not in this list.

  ## Compile-time checks

  `param` raises an `ArgumentError` at compile time in these cases:

  - The type is not a built-in type or a module that implements
    `Commandex.Type`.
  - An option is not valid.
  - The default is not valid for the type.
  - The type is `:decimal` and the `:decimal` package is not installed.
  """
  @spec param(atom(), Commandex.Type.t() | Keyword.t(), Keyword.t()) :: no_return()
  defmacro param(name, type_or_opts \\ :any, opts \\ []) do
    quote do
      Commandex.__param__(__MODULE__, unquote(name), unquote(type_or_opts), unquote(opts))
    end
  end

  @doc """
  Defines a command data field.

  Data field values are created and set as pipelines are run. Set one with `put_data/3`.

      command do
        # ...params

        data :password_hash
        data :user

        # ...pipelines
      end
  """
  @spec data(atom()) :: no_return()
  defmacro data(name) do
    quote do
      Commandex.__data__(__MODULE__, unquote(name))
    end
  end

  @doc """
  Defines a command pipeline.

  Pipelines are functions executed against the command, *in the order in which they are defined*.

  For example, two pipelines could be defined:

      pipeline :check_valid_email
      pipeline :create_user

  Which could be mentally interpreted as:

      command
      |> check_valid_email()
      |> create_user()

  A pipeline function can be defined multiple ways:

  - `pipeline :do_work` - Name of a function inside the command's module, arity three.
  - `pipeline {YourModule, :do_work}` - Arity three.
  - `pipeline {YourModule, :do_work, [:additional, "args"]}` - Arity three plus the
    number of additional args given.
  - `pipeline &YourModule.do_work/1` - Or any anonymous function of arity one.
  - `pipeline &YourModule.do_work/3` - Or any anonymous function of arity three.
  """
  @spec pipeline(atom()) :: no_return()
  defmacro pipeline(name) do
    quote do
      Commandex.__pipeline__(__MODULE__, unquote(name))
    end
  end

  @doc """
  Sets a data field with given value.

  Define a data field first:

      data :password_hash

  Set the password hash in one of your pipeline functions:

      def hash_password(command, %{password: password} = _params, _data) do
        # Better than plaintext, I guess
        put_data(command, :password_hash, Base.encode64(password))
      end
  """
  @spec put_data(command(), atom(), any()) :: command()
  def put_data(%{data: data} = command, key, val) do
    %{command | data: Map.put(data, key, val)}
  end

  @doc """
  Sets error for given key and value.

  `:errors` is a map. Putting an error on the same key will overwrite the previous value.

      def hash_password(command, %{password: nil} = _params, _data) do
        command
        |> put_error(:password, :not_supplied)
        |> halt()
      end
  """
  @spec put_error(command(), any(), any()) :: command()
  def put_error(%{errors: error} = command, key, val) do
    %{command | errors: Map.put(error, key, val)}
  end

  @doc """
  Halts a command pipeline.

  Any pipelines defined after the halt will be ignored. By default, if a command finishes
  running through all pipelines, `:success` will be set to `true`.

      def hash_password(command, %{password: nil} = _params, _data) do
        command
        |> put_error(:password, :not_supplied)
        |> halt()
      end

  ### Halting Early Successfully

  Pass `success: true` as an optional argument if you would like to mark the command
  as successful, even if there are still pipelines left to be run. Useful for returning
  early from no-op commands.

      def needs_update?(command, _params, _data) do
        command
        |> put_error(:update, :no_op)
        |> halt(success: true)
      end
  """
  @spec halt(command(), Keyword.t()) :: command()
  def halt(command, opts \\ []) do
    success = Keyword.get(opts, :success, false)
    %{command | halted: true, success: success}
  end

  @doc """
  Halts the command if any errors are present.

  `new/1` calls this after it casts the parameters, so a command with a
  cast error or a missing required parameter does not run any pipelines.
  It can also be used as a pipeline to collect custom validation errors
  before the command continues.

      command do
        param :email, :string, required: true
        param :age, :integer

        pipeline :validate_age
        pipeline &Commandex.halt_on_errors/1
        pipeline :create_user
      end
  """
  @spec halt_on_errors(command()) :: command()
  def halt_on_errors(%{errors: errors} = command) when errors == %{}, do: command
  def halt_on_errors(command), do: halt(command)

  @doc false
  @spec run_pipelines(command(), [pipeline()]) :: command()
  def run_pipelines(%{halted: true} = command, _pipelines) do
    command
  end

  def run_pipelines(command, pipelines) do
    pipelines
    |> Enum.reduce_while(command, fn fun, acc ->
      case acc do
        %{halted: false} -> {:cont, apply_fun(acc, fun)}
        _ -> {:halt, acc}
      end
    end)
    |> maybe_mark_successful()
  end

  @doc false
  @spec maybe_mark_successful(command()) :: command()
  def maybe_mark_successful(%{halted: false} = command), do: %{command | success: true}
  def maybe_mark_successful(command), do: command

  @doc false
  @spec apply_fun(command(), pipeline()) :: command()
  def apply_fun(%mod{params: params, data: data} = command, name) when is_atom(name) do
    :erlang.apply(mod, name, [command, params, data])
  end

  def apply_fun(command, fun) when is_function(fun, 1) do
    fun.(command)
  end

  def apply_fun(%{params: params, data: data} = command, fun) when is_function(fun, 3) do
    fun.(command, params, data)
  end

  def apply_fun(%{params: params, data: data} = command, {m, f}) do
    :erlang.apply(m, f, [command, params, data])
  end

  def apply_fun(%{params: params, data: data} = command, {m, f, a}) do
    :erlang.apply(m, f, [command, params, data] ++ a)
  end

  @doc false
  @spec __param__(module(), atom(), Commandex.Type.t() | Keyword.t(), Keyword.t()) :: :ok
  def __param__(mod, name, type_or_opts, opts)

  def __param__(mod, name, opts, []) when is_list(opts) do
    __param__(mod, name, :any, opts)
  end

  def __param__(mod, name, type, opts) do
    params = Module.get_attribute(mod, :params)

    if List.keyfind(params, name, 0) do
      raise ArgumentError, "param #{inspect(name)} is already set on command"
    end

    Module.put_attribute(mod, :params, {name, Commandex.Parameter.define!(name, type, opts)})
  end

  @doc false
  @spec __data__(module(), atom()) :: :ok
  def __data__(mod, name) do
    data = Module.get_attribute(mod, :data)

    if List.keyfind(data, name, 0) do
      raise ArgumentError, "data #{inspect(name)} is already set on command"
    end

    Module.put_attribute(mod, :data, {name, nil})
  end

  @doc false
  @spec __pipeline__(module(), pipeline()) :: :ok
  def __pipeline__(mod, name) when is_atom(name) do
    Module.put_attribute(mod, :pipelines, name)
  end

  def __pipeline__(mod, fun) when is_function(fun, 1) do
    Module.put_attribute(mod, :pipelines, fun)
  end

  def __pipeline__(mod, fun) when is_function(fun, 3) do
    Module.put_attribute(mod, :pipelines, fun)
  end

  def __pipeline__(mod, {m, f}) do
    Module.put_attribute(mod, :pipelines, {m, f})
  end

  def __pipeline__(mod, {m, f, a}) do
    Module.put_attribute(mod, :pipelines, {m, f, a})
  end

  def __pipeline__(_mod, name) do
    raise ArgumentError, "pipeline #{inspect(name)} is not valid"
  end
end
