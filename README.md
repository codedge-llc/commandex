[![CI](https://github.com/codedge-llc/commandex/actions/workflows/ci.yml/badge.svg)](https://github.com/codedge-llc/commandex/actions/workflows/ci.yml)
[![Hex.pm](http://img.shields.io/hexpm/v/commandex.svg)](https://hex.pm/packages/commandex)
[![Hex.pm](http://img.shields.io/hexpm/dt/commandex.svg)](https://hex.pm/packages/commandex)

# Commandex

> Make Elixir actions a first-class data type.

Commandex structs are a loose implementation of the command pattern, making it easy
to wrap parameters, data, and errors into a well-defined struct.

## Installation

Add commandex as a `mix.exs` dependency:

```elixir
def deps do
  [
    {:commandex, "~> 0.4.1"}
  ]
end
```

## Example Usage

A fully implemented command module might look like this:

```elixir
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
```

The `command/1` macro will define a struct that looks like:

```elixir
%RegisterUser{
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
or map with atom/string keys.

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

Copyright (c) 2020-2024 Codedge LLC (https://www.codedge.io/)

This library is MIT licensed. See the [LICENSE](https://github.com/codedge-llc/commandex/blob/master/LICENSE) for details.
