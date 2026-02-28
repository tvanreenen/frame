#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh
source ./script/identity.sh

./build-debug.sh > /dev/null || ./build-debug.sh
"./.debug/${FRAME_CLI_NAME}" "$@"
