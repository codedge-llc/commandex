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
          param :email
          param :password

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
        __meta__: %{
          pipelines: [:hash_password, :create_user, :send_welcome_email]
        },
        success: false,
        halted: false,
        errors: %{},
        params: %{email: nil, password: nil},
        data: %{password_hash: nil, user: nil},
      }

  As well as two functions:

      &RegisterUser.new/1
      &RegisterUser.run/1

  `&new/1` parses parameters into a new struct. These can be either a keyword list
  or map with atom/string keys.

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

        %{success: false, errors: _error} ->
          # I'm a lazy programmer that writes catch-all error handling
      end

  ## Parameter-less Commands

  If a command does not have any parameters defined, a `run/0` will be generated
  automatically. Useful for diagnostic jobs and internal tasks.

      iex> GenerateReport.run()
      %GenerateReport{
        __meta__: %{
          params: %{},
          pipelines: [:fetch_data, :calculate_results],
        },
        data: %{total_valid: 183220, total_invalid: 781215},
        errors: %{},
        halted: false,
        params: %{},
        success: true,
        valid: true
      }
  """

  @typedoc """
  Command pipeline stage.

  A pipeline function can be defined multiple ways:

  - `pipeline :do_work` - Name of a function inside the command's module, arity three.
  - `pipeline {YourModule, :do_work}` - Arity three.
  - `pipeline {YourModule, :do_work, [:additonal, "args"]}` - Arity three plus the 
    number of additional args given.
  - `pipeline &YourModule.do_work/1` - Or any anonymous function of arity one.
  - `pipeline &YourModule.do_work/3` - Or any anonymous function of arity three.
  """
  @type pipeline ::
          atom
          | {module, atom}
          | {module, atom, [any]}
          | (command :: struct -> command :: struct)
          | (command :: struct, params :: map, data :: map -> command :: struct)

  @typedoc """
  Command struct.

  ## Attributes

  - `data` - Data generated during the pipeline, defined by `Commandex.data/1`.
  - `errors` - Errors generated during the pipeline with `Commandex.put_error/3`
  - `halted` - Whether or not the pipeline was halted.
  - `params` - Parameters given to the command, defined by `Commandex.param/1`.
  - `pipelines` - A list of pipeline functions to execute, defined by `Commandex.pipeline/1`.
  - `success` - Whether or not the command was successful. This is only set to
    `true` if the command was not halted after running all of the pipelines.
  """
  @type command :: %{
          __struct__: atom,
          __meta__: %{
            pipelines: [pipeline()]
          },
          data: map,
          errors: map,
          halted: boolean,
          params: map,
          success: boolean
        }

  @doc """
  Defines a command struct with params, data, and pipelines.
  """
  @spec command(do: any) :: no_return
  defmacro command(do: block) do
    prelude =
      quote do
        for name <- [:struct_fields, :params, :data, :pipelines] do
          Module.register_attribute(__MODULE__, name, accumulate: true)
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
        data = __MODULE__ |> Module.get_attribute(:data) |> Enum.into(%{})
        params = __MODULE__ |> Module.get_attribute(:params) |> Enum.into(%{})
        pipelines = __MODULE__ |> Module.get_attribute(:pipelines) |> Enum.reverse()
        schema = %{params: params, pipelines: pipelines}

        # Added in reverse order so the struct fields sort alphabetically.
        Module.put_attribute(__MODULE__, :struct_fields, {:valid, false})
        Module.put_attribute(__MODULE__, :struct_fields, {:success, false})
        Module.put_attribute(__MODULE__, :struct_fields, {:params, %{}})
        Module.put_attribute(__MODULE__, :struct_fields, {:halted, false})
        Module.put_attribute(__MODULE__, :struct_fields, {:errors, %{}})
        Module.put_attribute(__MODULE__, :struct_fields, {:data, data})
        Module.put_attribute(__MODULE__, :struct_fields, {:__meta__, schema})

        defstruct @struct_fields

        @typedoc """
        Command struct.

        ## Attributes

        - `data` - Data generated during the pipeline, defined by `Commandex.data/1`.
        - `errors` - Errors generated during the pipeline with `Commandex.put_error/3`
        - `halted` - Whether or not the pipeline was halted.
        - `params` - Parameters given to the command, defined by `Commandex.param/1`.
        - `pipelines` - A list of pipeline functions to execute, defined by `Commandex.pipeline/1`.
        - `success` - Whether or not the command was successful. This is only set to
          `true` if the command was not halted after running all of the pipelines.
        """
        @type t :: %__MODULE__{
                __meta__: %{
                  pipelines: [Commandex.pipeline()]
                },
                data: map,
                errors: map,
                halted: boolean,
                params: map,
                success: boolean | nil,
                valid: boolean | nil
              }

        @doc """
        Creates a new struct from given parameters.
        """
        @spec new(map | Keyword.t()) :: t
        def new(params \\ []) do
          Commandex.Parameter.cast_params(%__MODULE__{}, params)
        end

        if Enum.empty?(params) do
          @doc """
          Runs given pipelines in order and returns command struct.
          """
          @spec run :: t
          def run do
            new() |> run()
          end
        end

        @doc """
        Runs given pipelines in order and returns command struct.

        `run/1` can either take parameters that would be passed to `new/1`
        or the command struct itself.
        """
        @spec run(map | Keyword.t() | t) :: t
        def run(%unquote(__MODULE__){__meta__: %{pipelines: pipelines}} = command) do
          pipelines
          |> Enum.reduce_while(command, fn fun, acc ->
            case acc do
              %{halted: false} -> {:cont, Commandex.apply_fun(acc, fun)}
              _ -> {:halt, acc}
            end
          end)
          |> Commandex.maybe_mark_successful()
        end

        def run(params) do
          params
          |> new()
          |> run()
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

      command do
        param :email
        param :password

        # ...data
        # ...pipelines
      end
  """
  @spec param(atom, Keyword.t()) :: no_return
  defmacro param(name, type \\ :any, opts \\ []) do
    quote do
      Commandex.__param__(__MODULE__, unquote(name), unquote(type), unquote(opts))
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
  @spec data(atom) :: no_return
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
  - `pipeline {YourModule, :do_work, [:additonal, "args"]}` - Arity three plus the 
    number of additional args given.
  - `pipeline &YourModule.do_work/1` - Or any anonymous function of arity one.
  - `pipeline &YourModule.do_work/3` - Or any anonymous function of arity three.
  """
  @spec pipeline(atom) :: no_return
  defmacro pipeline(name) do
    quote do
      Commandex.__pipeline__(__MODULE__, unquote(name))
    end
  end

  @doc """
  Sets a data field with given value.

  Define a data field first:

      data :password_hash

  Set the password pash in one of your pipeline functions:

      def hash_password(command, %{password: password} = _params, _data) do
        # Better than plaintext, I guess
        put_data(command, :password_hash, Base.encode64(password))
      end
  """
  @spec put_data(command, atom, any) :: command
  def put_data(%{data: data} = command, key, val) do
    %{command | data: Map.put(data, key, val)}
  end

  @doc """
  Sets error for given key and value.

  `:errors` is a map. Putting an error on the same key will create a list.

      def hash_password(command, %{password: nil} = _params, _data) do
        command
        |> put_error(:password, :not_supplied)
        |> halt()
      end
  """
  @spec put_error(command, any, any) :: command
  def put_error(%{errors: errors} = command, key, val) do
    case Map.get(errors, key) do
      nil -> %{command | errors: Map.put(errors, key, val)}
      vals when is_list(vals) -> %{command | errors: Map.put(errors, key, [val | vals])}
      value -> %{command | errors: Map.put(errors, key, [val, value])}
    end
  end

  @doc """
  Halts a command pipeline.

  Any pipelines defined after the halt will be ignored. If a command finishes running through
  all pipelines, `:success` will be set to `true`.

      def hash_password(command, %{password: nil} = _params, _data) do
        command
        |> put_error(:password, :not_supplied)
        |> halt()
      end
  """
  @spec halt(command) :: command
  def halt(command), do: %{command | halted: true}

  @doc false
  def maybe_mark_successful(%{halted: false} = command), do: %{command | success: true}
  def maybe_mark_successful(command), do: %{command | success: false}

  @doc false
  def maybe_mark_invalid(command) do
    %{command | valid: Enum.empty?(command.errors)}
  end

  @doc false
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

  # If no type is defined, opts keyword list becomes third argument.
  # Run this again with the :any type.
  def __param__(mod, name, opts, []) when is_list(opts) do
    __param__(mod, name, :any, opts)
  end

  def __param__(mod, name, type, opts) do
    Commandex.Parameter.check_type!(name, type)

    params = Module.get_attribute(mod, :params)

    if Enum.any?(params, fn {p_name, _opts} -> p_name == name end) do
      raise ArgumentError, "param #{inspect(name)} is already set on command"
    end

    Module.put_attribute(mod, :params, {name, {type, opts}})
  end

  def __data__(mod, name) do
    data = Module.get_attribute(mod, :data)

    if List.keyfind(data, name, 0) do
      raise ArgumentError, "data #{inspect(name)} is already set on command"
    end

    Module.put_attribute(mod, :data, {name, nil})
  end

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
