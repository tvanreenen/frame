#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

banned_tokens='AeroSpace|aerospace|simple-wm|simplewm|SIMPLEWM_|AEROSPACE_'
allowlist_globs=(
    --glob '!axDumps/**'
    --glob '!legal/**'
    --glob '!AGENTS.md'
    --glob '!script/check-naming-hygiene.sh'
    --glob '!.build/**'
    --glob '!.deps/**'
    --glob '!.xcode-build/**'
    --glob '!.release/**'
)

if command -v rg > /dev/null 2>&1; then
    matches="$(rg -n "$banned_tokens" . "${allowlist_globs[@]}" || true)"
else
    matches="$(grep -RInE "$banned_tokens" . \
        --exclude-dir=.git \
        --exclude-dir=axDumps \
        --exclude-dir=legal \
        --exclude-dir=.build \
        --exclude-dir=.deps \
        --exclude-dir=.xcode-build \
        --exclude-dir=.release \
        --exclude=AGENTS.md \
        --exclude=check-naming-hygiene.sh \
        --binary-files=without-match || true)"
fi
if test -n "$matches"; then
    echo "Found banned legacy naming tokens. Allowed locations: axDumps/**, legal/**, AGENTS.md" >&2
    echo "$matches" >&2
    exit 1
fi

echo "Naming hygiene check passed"
