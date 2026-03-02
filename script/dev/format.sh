#!/usr/bin/env bash
cd "$(dirname "$0")/../.."
source ./script/setup.sh

verify_only=0
while test $# -gt 0; do
    case $1 in
        --verify) verify_only=1; shift 1 ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

require_command swiftformat
require_command swiftlint
if test $verify_only -eq 1; then
    swiftformat --lint .
    swiftlint lint --quiet
else
    swiftformat .
    swiftlint lint --quiet --fix
fi
