defmodule TursoxProcedures.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/mindreframer/tursox_procedures"
  @authors ["Roman Heinrich <roman.heinrich@gmail.com>"]

  def project do
    [
      app: :tursox_procedures,
      version: @version,
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: "Sandboxed, transactional Lua procedures for Tursox",
      source_url: @source_url,
      homepage_url: @source_url,
      authors: @authors,
      package: package(),
      docs: docs(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:tursox, "== 0.2.1"},
      {:lua, "== 1.0.2"},
      {:telemetry, "== 1.4.2"},
      {:jason, "== 1.4.5"},
      {:ex_doc, "== 0.40.3", only: :dev, runtime: false}
    ]
  end

  defp aliases, do: [test: "test --no-start"]

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "SECURITY.md",
        "THIRD_PARTY_NOTICES.md",
        "docs/architecture.md",
        "docs/catalog.md",
        "docs/lua-api.md",
        "docs/composition.md",
        "docs/security-and-limits.md",
        "docs/operations.md",
        "docs/compatibility.md"
      ],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: @authors,
      links: %{
        "Source" => @source_url,
        "Tursox" => "https://github.com/mindreframer/tursox"
      },
      build_tools: ["mix"],
      files: [
        "lib",
        ".formatter.exs",
        "mix.exs",
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        "SECURITY.md",
        "THIRD_PARTY_NOTICES.md",
        "docs"
      ]
    ]
  end
end
