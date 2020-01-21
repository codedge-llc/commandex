defmodule Commandex do
  @moduledoc """
  Defines a command struct.

  Commandex structs are a loose implementation of the command pattern, making it easy
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
        success: false,
        halted: false,
        error: %{},
        params: %{email: nil, password: nil},
        data: %{password_hash: nil, user: nil},
        pipelines: [:hash_password, :create_user, :send_welcome_email]
      }

  As well as two functions:

      &RegisterUser.new/1
      &RegisterUser.run/1

  `&new/1` parses parameters into a new struct. These can be either a keyword list
  or map with atom/string keys.

  `&run/1` takes a command struct and runs it through the pipeline functions defined
  in the command. Functions are executed *in the order in which they are defined*.
  If a command passes through all pipelines without calling `halt/1`, `:success` 
  will be set to `true`. Otherwise, subsequent pipelines after the `halt/1` will 
  be ignored and `:success` will be set to `false`.

  ## Example 

      %{email: "example@example.com", password: "asdf1234"}
      |> RegisterUser.new()
      |> RegisterUser.run()
      |> case do
        %{success: true, data: %{user: user}} ->
          # Success! We've got a user now

        %{success: false, error: %{password: :not_given}} ->
          # Respond with a 400 or something

        %{success: false, error: _error} ->
          # I'm a lazy programmer that writes catch-all error handling
      end
  """

  @type command :: %{
          __struct__: atom,
          data: map,
          error: map,
          halted: boolean,
          params: map,
          pipelines: [atom | {module, atom} | function],
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
        params = for pair <- Module.get_attribute(__MODULE__, :params), into: %{}, do: pair
        data = for pair <- Module.get_attribute(__MODULE__, :data), into: %{}, do: pair
        pipelines = __MODULE__ |> Module.get_attribute(:pipelines) |> Enum.reverse()

        Module.put_attribute(__MODULE__, :struct_fields, {:params, params})
        Module.put_attribute(__MODULE__, :struct_fields, {:data, data})
        Module.put_attribute(__MODULE__, :struct_fields, {:pipelines, pipelines})
        defstruct @struct_fields

        @doc """
        Creates a new #{__MODULE__} struct from given params.
        """
        def new(opts) do
          Commandex.parse_params(%__MODULE__{}, opts)
        end

        def run(%unquote(__MODULE__){pipelines: pipelines} = command) do
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
  @spec param(atom) :: no_return
  defmacro param(name) do
    quote do
      Commandex.__param__(__MODULE__, unquote(name))
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

  A pipeline function must be of arity three (command, params, data), but can be defined multiple ways:

      pipline :create_user # The name of a function inside the command's module
      pipeline &YourModule.create_user/3
      pipeline {YourModule, :create_user} 
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
  Sets an error for given key and value.

  `:error` is a map. Putting an error on the same key will overwrite the previous value.

      def hash_password(command, %{password: nil} = _params, _data) do
        command
        |> put_error(:password, :not_supplied)
        |> halt()
      end
  """
  @spec put_error(command, any, any) :: command
  def put_error(%{error: error} = command, key, val) do
    %{command | error: Map.put(error, key, val)}
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
  def maybe_mark_successful(command), do: command

  @doc false
  def parse_params(%{params: p} = struct, params) when is_list(params) do
    params = for {key, _} <- p, into: %{}, do: {key, Keyword.get(params, key)}
    %{struct | params: params}
  end

  def parse_params(%{params: p} = struct, %{} = params) do
    params = for {key, _} <- p, into: %{}, do: {key, get_param(params, key)}
    %{struct | params: params}
  end

  @doc false
  def apply_fun(%mod{params: params, data: data} = command, name) when is_atom(name) do
    :erlang.apply(mod, name, [command, params, data])
  end

  def apply_fun(%{params: params, data: data} = command, fun) when is_function(fun) do
    fun.(command, params, data)
  end

  def apply_fun(%{params: params, data: data} = command, {m, f}) do
    :erlang.apply(m, f, [command, params, data])
  end

  def apply_fun(%{params: params, data: data} = command, {m, f, a}) do
    :erlang.apply(m, f, [command, params, data] ++ a)
  end

  def __param__(mod, name) do
    params = Module.get_attribute(mod, :params)

    if List.keyfind(params, name, 0) do
      raise ArgumentError, "param #{inspect(name)} is already set on command"
    end

    Module.put_attribute(mod, :params, {name, nil})
  end

  def __data__(mod, name) do
    data = Module.get_attribute(mod, :data)

    if List.keyfind(data, name, 0) do
      raise ArgumentError, "data #{inspect(name)} is already set on command"
    end

    Module.put_attribute(mod, :data, {name, nil})
  end

  def __pipeline__(mod, name) do
    Module.put_attribute(mod, :pipelines, name)
  end

  defp get_param(params, key) do
    case Map.get(params, key) do
      nil -> Map.get(params, to_string(key))
      val -> val
    end
  end
end
