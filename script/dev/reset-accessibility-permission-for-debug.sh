#!/bin/bash
cd "$(dirname "$0")/../.."
source ./script/setup.sh
source ./script/identity.sh

/usr/bin/tccutil reset Accessibility "$FRAME_BUNDLE_ID_DEBUG"
