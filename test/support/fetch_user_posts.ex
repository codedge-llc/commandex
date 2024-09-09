defmodule FetchUserPosts do
  @moduledoc """
  Example command that fetches posts for a given user.
  """

  import Commandex

  command do
    param :user_id, :integer, required: true
    param :limit, :integer, default: 20
    param :offset, :integer, default: 0
    param :sort_by, {:array, :string}, default: ["created_at"]
    param :sort_dir, {:array, :string}, default: ["asc"]

    data :posts

    pipeline :fetch_posts
  end

  # def validate(command, params, _data) do
  #   command
  #   |> validate_number(:limit, in: 0..100)
  #   |> validate_number(:offset, greater_than_or_equal: 0)
  #   |> halt_if_invalid()
  # end

  def fetch_posts(command, _params, _data) do
    command
  end
end
