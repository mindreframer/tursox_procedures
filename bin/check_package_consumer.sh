#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_dir="${project_root}/_build/qa/package"
consumer_dir="${project_root}/_build/qa/consumer"
rm -rf "${package_dir}" "${consumer_dir}"
mkdir -p "${consumer_dir}"

cd "${project_root}"
mix hex.build --unpack --output "${package_dir}" >/dev/null

test -f "${package_dir}/lib/tursox/procedures.ex"
test ! -e "${package_dir}/test"
test ! -e "${package_dir}/@meta"

cat >"${consumer_dir}/mix.exs" <<EOF
defmodule TursoxProceduresConsumer.MixProject do
  use Mix.Project
  def project do
    [
      app: :tursox_procedures_consumer,
      version: "0.0.0",
      elixir: "~> 1.20",
      deps: [{:tursox_procedures, path: "${package_dir}"}]
    ]
  end
  def application, do: [extra_applications: [:logger]]
end
EOF

cat >"${consumer_dir}/smoke.exs" <<'EOF'
{:ok, _} = Application.ensure_all_started(:tursox_procedures)
{:ok, pool} = Tursox.Pool.start_link(database: :memory, pool_size: 1)
{:ok, source} = Tursox.Procedures.Source.Memory.start_link()
{:ok, _} = Tursox.Procedures.Source.Memory.publish(source, "smoke", "return args.value")
{:ok, procedures} =
  Tursox.Procedures.start_link(
    pool: pool,
    source: {Tursox.Procedures.Source.Memory, source}
  )

{:ok, %Tursox.Procedures.Result{value: 42}} =
  Tursox.Procedures.call(procedures, "smoke", %{"value" => 42})

:ok = Tursox.Procedures.stop(procedures)
:ok = GenServer.stop(source)
:ok = Tursox.Pool.stop(pool)
IO.puts("clean package consumer passed")
EOF

cd "${consumer_dir}"
MIX_ENV=prod mix deps.get --only prod >/dev/null
MIX_ENV=prod mix compile --warnings-as-errors >/dev/null
MIX_ENV=prod mix run --no-start smoke.exs
