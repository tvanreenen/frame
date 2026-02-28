#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh
source ./script/identity.sh

./build-debug.sh
"./.debug/${FRAME_DEBUG_APP_BINARY}" "$@"
