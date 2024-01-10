defmodule Commandex.MixProject do
  use Mix.Project

  @version "0.4.1"

  def project do
    [
      app: :commandex,
      deps: deps(),
      description: description(),
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      name: "Commandex",
      package: package(),
      source_url: "https://github.com/codedge-llc/commandex",
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    """
    Make complex actions a first-class data type.
    """
  end

  defp package do
    [
      files: ~w(lib mix.exs .formatter.exs README* LICENSE*),
      maintainers: ["Henry Popp", "Tyler Hurst"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/codedge-llc/commandex"}
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
