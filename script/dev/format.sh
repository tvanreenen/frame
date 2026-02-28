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

./script/install-dep.sh --swiftformat
./script/install-dep.sh --swiftlint
if test $verify_only -eq 1; then
    ./.deps/swiftformat/swiftformat --lint .
    ./.deps/swiftlint/swiftlint lint --quiet
else
    ./.deps/swiftformat/swiftformat .
    ./.deps/swiftlint/swiftlint lint --quiet --fix
fi
