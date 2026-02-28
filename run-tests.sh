#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh
source ./script/identity.sh

./script/check-uncommitted-files.sh
./script/check-naming-hygiene.sh

./build-debug.sh -Xswiftc -warnings-as-errors
./run-swift-test.sh

"./.debug/${FRAME_CLI_NAME}" -h > /dev/null
"./.debug/${FRAME_CLI_NAME}" --help > /dev/null
"./.debug/${FRAME_CLI_NAME}" -v | grep -q "0.0.0-SNAPSHOT SNAPSHOT"
"./.debug/${FRAME_CLI_NAME}" --version | grep -q "0.0.0-SNAPSHOT SNAPSHOT"

./format.sh --check-uncommitted-files

echo
echo "✅ All tests have passed successfully"
