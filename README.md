# Commandex

> Make Elixir actions a first-class data type.

[![CI](https://github.com/codedge-llc/commandex/actions/workflows/ci.yml/badge.svg)](https://github.com/codedge-llc/commandex/actions/workflows/ci.yml)
[![Version](https://img.shields.io/hexpm/v/commandex.svg)](https://hex.pm/packages/commandex)
[![Total Downloads](https://img.shields.io/hexpm/dt/commandex.svg)](https://hex.pm/packages/commandex)
[![License](https://img.shields.io/hexpm/l/commandex.svg)](https://github.com/codedge-llc/commandex/blob/main/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/codedge-llc/commandex.svg)](https://github.com/codedge-llc/commandex/commits/main)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/commandex/)

Commandex structs are a loose implementation of the command pattern, making it easy
to wrap parameters, data, and errors into a well-defined struct.

## Installation

Add commandex as a `mix.exs` dependency:

```elixir
def deps do
  [
    {:commandex, "~> 0.6.0"}
  ]
end
```

## Example Usage

A fully implemented command module might look like this:

```elixir
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
```

The `command/1` macro will define a struct that looks like:

```elixir
%RegisterUser{
  __meta__: #Commandex.Metadata<2 params>,
  success: false,
  halted: false,
  errors: %{},
  params: %{email: nil, password: nil},
  data: %{password_hash: nil, user: nil},
  pipelines: [:hash_password, :create_user, :send_welcome_email]
}
```

As well as two functions:

```elixir
&RegisterUser.new/1
&RegisterUser.run/1
```

`&new/1` parses parameters into a new struct. These can be either a keyword list
or map with atom/string keys. If a parameter has a type, `&new/1` casts the value
to that type.

`&run/1` takes a command struct and runs it through the pipeline functions defined
in the command. Functions are executed _in the order in which they are defined_.
If a command passes through all pipelines without calling `halt/1`, `:success`
will be set to `true`. Otherwise, subsequent pipelines after the `halt/1` will
be ignored and `:success` will be set to `false`.

Running a command is easy:

```elixir
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
```

For even leaner implementations, you can run a command by passing
the params directly into `&run/1` without using `&new/1`:

```elixir
%{email: "example@example.com", password: "asdf1234"}
|> RegisterUser.run()
```

## Typed Parameters

A parameter can declare a type. `&new/1` casts the value to that type. The
built-in types follow the cast rules of Ecto, so `"42"` is a valid `:integer`
and `42.0` is not.

```elixir
command do
  param :email, :string, required: true
  param :age, :integer
  param :starts_on, :date
  param :price, :decimal, default: "0.00"
  param :tags, {:array, :string}
  param :status, MyApp.Types.Enum, values: [:active, :pending_review]
  param :note
end
```

A parameter without a type, such as `:note`, keeps its value as given.

The built-in types are `:any`, `:binary`, `:boolean`, `:date`, `:decimal`, `:float`,
`:integer`, `:map`, `:naive_datetime`, `:naive_datetime_usec`, `:string`, `:time`,
`:time_usec`, `:utc_datetime`, `:utc_datetime_usec`, `{:array, type}`, and
`{:map, type}`. The `:decimal` type needs the optional
[decimal](https://hex.pm/packages/decimal) package, version 3.0 or later.

A module that implements the `Commandex.Type` behaviour can also be a type. See the
[Commandex.Type documentation](https://hexdocs.pm/commandex/Commandex.Type.html) for
an example, and for types that take options such as `MyApp.Types.Enum` above.

If a cast fails, the parameter keeps its default and gets an `:invalid` error. If a
parameter with `required: true` has no value, it gets a `:required` error. `&new/1`
halts a command that has an error, so `&run/1` does not run its pipelines.

```elixir
command = RegisterUser.run(%{password: 42})

command.success
#=> false

command.errors
#=> %{email: :required, password: :invalid}
```

## Contributing

### Testing

Unit tests can be run with `mix test`.

### Formatting

This project uses Elixir's `mix format` and [Prettier](https://prettier.io) for formatting.
Add hooks in your editor of choice to run it after a save. Be sure it respects this project's
`.formatter.exs`.

### Commits

Git commit subjects use the [Karma style](http://karma-runner.github.io/5.0/dev/git-commit-msg.html).

## License

Copyright (c) 2020-2026 Codedge LLC (https://www.codedge.io/)

This library is MIT licensed. See the [LICENSE](https://github.com/codedge-llc/commandex/blob/main/LICENSE) for details.
