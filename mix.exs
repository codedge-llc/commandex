defmodule Commandex.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :commandex,
      deps: [],
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
