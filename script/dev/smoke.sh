#!/bin/bash
cd "$(dirname "$0")/../.."
source ./script/setup.sh
source ./script/identity.sh

./script/dev/smoke-build.sh -Xswiftc -warnings-as-errors

"./.debug/${FRAME_CLI_NAME}" -h > /dev/null
"./.debug/${FRAME_CLI_NAME}" --help > /dev/null
"./.debug/${FRAME_CLI_NAME}" -v | grep -q "0.0.0-dev"
"./.debug/${FRAME_CLI_NAME}" --version | grep -q "0.0.0-dev"

echo
echo "✅ CLI smoke checks passed"
