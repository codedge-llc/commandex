defmodule Commandex.MixProject do
  use Mix.Project

  @source_url "https://github.com/codedge-llc/commandex"
  @version "0.4.1"

  def project do
    [
      app: :commandex,
      deps: deps(),
      docs: docs(),
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

  defp docs do
    [
      extras: [
        "CHANGELOG.md",
        LICENSE: [title: "License"]
      ],
      formatters: ["html"],
      main: "Commandex",
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp package do
    [
      description: "Make complex actions a first-class data type.",
      files: ["lib", "mix.exs", "README*", "LICENSE*", "CHANGELOG*"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/commandex/changelog.html",
        "GitHub" => "https://github.com/codedge-llc/commandex",
        "Sponsor" => "https://github.com/sponsors/codedge-llc"
      },
      maintainers: ["Henry Popp", "Tyler Hurst"]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
