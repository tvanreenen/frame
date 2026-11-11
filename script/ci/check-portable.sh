#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."

actionlint
while IFS= read -r -d '' shell_file; do
    bash -n "$shell_file"
done < <(git ls-files -z -- '*.sh')
./Tests/Shell/release-contract-test.sh
python3 -m unittest discover -s Tests/CI -v
