#!/usr/bin/env bash
# Run every variant several times and write a comparison table.
#
# Usage: bench/local/matrix.sh [repeats] [variant ...]
#
# Defaults to 3 repeats of every file in bench/local/variants/, in the order
# the server changed. Runs take 3 to 6 minutes each. The table goes to
# results/local/<date>-comparison.md.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
repeats=${1:-3}
shift || true
variants=("$@")
if [[ ${#variants[@]} -eq 0 ]]; then
  variants=(gorilla nbio-initial nbio-fixes nbio-ipv4 nbio-memlimit nbio-guard nbio-tuned)
fi

dirs=()
for i in $(seq "$repeats"); do
  for v in "${variants[@]}"; do
    echo "==> run $i of $repeats: $v"
    out=$("$here/run.sh" "$v" "${TOTAL:-300000}" "${REPLICAS:-5}" | tee /dev/stderr | sed -n 's/^==> results in //p')
    dirs+=("$root/$out")
  done
done

table="$root/results/local/$(date +%F)-comparison.md"
{
  echo "# Local comparison, $(date +%F)"
  echo
  echo "Each variant ran $repeats times with the same limits (see environment.md in each run directory)."
  echo "Values are medians, with the range in brackets."
  echo
  python3 "$here/compare.py" "${dirs[@]}"
  echo
  echo "Runs:"
  echo
  for d in "${dirs[@]}"; do echo "- \`${d#"$root"/}\`"; done
} >"$table"
echo "==> table in ${table#"$root"/}"
