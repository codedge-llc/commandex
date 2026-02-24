defmodule RegisterUser do
  @moduledoc """
  Example command that registers a user.
  """

  import Commandex

  command do
    param(:email, :string, default: "test@test.com")
    param :password, :string
    param :agree_tos, :boolean

    data :user
    data :auth

    pipeline :check_already_registered
    pipeline :verify_tos
    pipeline :create_user
    pipeline :record_auth_attempt
  end

  @spec check_already_registered(t(), map(), map()) :: t()
  def check_already_registered(command, %{email: email}, _data) do
    case email do
      "exists@test.com" ->
        command
        |> put_error(:user, :already_exists)
        |> halt(success: true)

      _other ->
        command
    end
  end

  @spec verify_tos(t(), map(), map()) :: t()
  def verify_tos(command, %{agree_tos: true} = _params, _data) do
    command
  end

  def verify_tos(command, %{agree_tos: false} = _params, _data) do
    command
    |> put_error(:tos, :not_accepted)
    |> halt()
  end

  @spec create_user(t(), map(), map()) :: t()
  def create_user(command, %{password: nil} = _params, _data) do
    command
    |> put_error(:password, :not_given)
    |> halt()
  end

  def create_user(command, %{email: email} = _params, _data) do
    put_data(command, :user, %{email: email})
  end

  @spec record_auth_attempt(t(), map(), map()) :: t()
  def record_auth_attempt(command, _params, _data) do
    put_data(command, :auth, true)
  end
end
