#!/usr/bin/env bash
set -uo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_root}"

log_root="${project_root}/_build/qa/latest"
rm -rf "${log_root}"
mkdir -p "${log_root}"

run_stage() {
  local key="$1"
  local label="$2"
  shift 2
  local log="${log_root}/${key}.log"
  local started=$SECONDS

  printf '[qa/%s] %s\n' "$key" "$label"
  if "$@" >"$log" 2>&1; then
    printf '[qa/%s] ok (%ss)\n' "$key" "$((SECONDS - started))"
  else
    local status=$?
    printf '[qa/%s] FAILED (exit %s, %ss)\n' "$key" "$status" "$((SECONDS - started))" >&2
    printf '%s\n' "--- last 40 lines; full log: ${log} ---" >&2
    tail -n 40 "$log" >&2 || true
    exit "$status"
  fi
}

run_live_stage() {
  local key="$1"
  local label="$2"
  shift 2
  local log="${log_root}/${key}.log"
  local started=$SECONDS

  printf '[qa/%s] %s\n' "$key" "$label"
  if "$@" 2>&1 | tee "$log"; then
    printf '[qa/%s] ok (%ss)\n' "$key" "$((SECONDS - started))"
  else
    local status=$?
    printf '[qa/%s] FAILED (exit %s, %ss); full log: %s\n' \
      "$key" "$status" "$((SECONDS - started))" "$log" >&2
    exit "$status"
  fi
}

run_stage deps "verify locked Elixir dependencies" \
  env MIX_ENV=test mix deps.get --check-locked
run_stage format "check Elixir formatting" mix format --check-formatted
run_stage compile "compile with warnings denied" \
  env MIX_ENV=test mix compile --warnings-as-errors
run_live_stage test "run deterministic ExUnit suite" \
  env MIX_ENV=test mix test --no-compile --seed 0
run_stage docs "build documentation with warnings denied" \
  env MIX_ENV=dev mix docs --warnings-as-errors
run_stage package "build and inspect the Hex package" \
  mix hex.build --output "${log_root}/tursox_procedures.tar"
run_stage consumer "compile and smoke an unpacked clean package consumer" \
  bin/check_package_consumer.sh

printf '[qa/ok] all 7 stages passed; logs: %s\n' "$log_root"
