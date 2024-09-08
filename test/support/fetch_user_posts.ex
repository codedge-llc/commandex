defmodule FetchUserPosts do
  @moduledoc """
  Example command that fetches posts for a given user.
  """

  import Commandex

  command do
    param :user_id, :integer, required: true
    param :limit, :integer, min: 0, max: 50, default: 20
    param :offset, :integer, min: 0, default: 0
    param :sort_by, {:array, :string}, default: ["created_at"]
    param :sort_dir, {:array, :string}, default: ["asc"]

    data :posts

    pipeline :fetch_posts
  end

  def fetch_posts(command, _params, _data) do
    command
  end
end
