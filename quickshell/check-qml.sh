#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C.UTF-8

cd "$(dirname "${BASH_SOURCE[0]}")"
for tool in qmlformat qmllint python3; do
  if ! command -v "$tool" >/dev/null; then
    printf 'Missing %s; run via nix-shell quickshell/qml-check.nix.\n' "$tool" >&2
    exit 1
  fi
done

mapfile -d '' files < <(find desktop lockscreen -type f -name '*.qml' -print0 | sort -z)
if ((${#files[@]} == 0)); then
  echo 'No QML files found.' >&2
  exit 1
fi

# Parse through qmlformat without modifying files or enforcing a mass reformat.
for file in "${files[@]}"; do
  printf 'qmlformat: %s\n' "$file"
  qmlformat "$file" >/dev/null
done

report=$(mktemp)
trap 'rm -f "$report"' EXIT
# Keep semantic warnings visible while initially gating syntax and missing modules.
# Inspect JSON too: some Qt releases exit successfully even with failed imports.
status=0
qmllint -E --max-warnings -1 --json "$report" "${files[@]}" || status=$?
python3 - "$report" <<'PY'
import json
import sys

with open(sys.argv[1]) as source:
    report = json.load(source)
if not report.get("files"):
    sys.exit("qmllint produced no file diagnostics")
failed = False
for file in report["files"]:
    for diagnostic in file.get("warnings", []):
        message = diagnostic["message"]
        print(f'{file["filename"]}:{diagnostic.get("line", 0)}: '
              f'{diagnostic["type"]}: {message}')
        if diagnostic["type"] == "error" or "Failed to import" in message:
            failed = True
sys.exit(1 if failed else 0)
PY
exit "$status"
