defmodule Commandex.RegisterUser do
  @params ~w(email password)a
  @data ~w(user auth)a

  use Commandex

  def pipeline do
    [
      &create_user/3,
      &record_auth_attempt/3
    ]
  end

  def create_user(command, %{password: nil} = _params, data) do
    command
    |> put_error(:no_password)
    |> halt()
  end

  def create_user(command, %{email: email} = _params, data) do
    put_data(command, :user, %{email: email})
  end

  def record_auth_attempt(command, _params, _data) do
    put_data(command, :auth, true)
  end
end
