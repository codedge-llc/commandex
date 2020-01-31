defmodule Commandex.RegisterUser do
  @moduledoc """
  Example command that registers a user.
  """

  import Commandex

  command do
    param :email, default: "test@test.com"
    param :password

    data :user
    data :auth

    pipeline :create_user
    pipeline :record_auth_attempt
    pipeline &IO.inspect/1
  end

  def create_user(command, %{password: nil} = _params, _data) do
    command
    |> put_error(:password, :not_given)
    |> halt()
  end

  def create_user(command, %{email: email} = _params, _data) do
    put_data(command, :user, %{email: email})
  end

  def record_auth_attempt(command, _params, _data) do
    put_data(command, :auth, true)
  end
end
