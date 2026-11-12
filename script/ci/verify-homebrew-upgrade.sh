#!/usr/bin/env bash
# Exercise the real old-to-new cask transition only on an ephemeral macOS runner.
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_OS:-}" == macOS && -n "${RUNNER_TEMP:-}" ]] || {
    echo 'Homebrew upgrade qualification requires a disposable macOS Actions runner' >&2; exit 1;
}
cd "$(dirname "$0")/../.."
version="${FRAME_CI_BUILD_VERSION:-3.3.0}"
archive="$(pwd)/dist/Frame-v${version}.zip"
[[ -f "$archive" ]]
prefix="$(brew --prefix)"
[[ ! -e /Applications/Frame.app && ! -e "$prefix/bin/frame" && ! -L "$prefix/bin/frame" ]] || {
    echo 'Refusing to change an existing Frame installation' >&2; exit 1;
}
export HOMEBREW_NO_AUTO_UPDATE=1
[[ -z "${HOMEBREW_NO_INSTALL_FROM_API:-}" ]] || { echo 'Homebrew API mode is required' >&2; exit 1; }
tap=tvr-works/frame-qualification
brew_ref="$tap/frame"
fixture="$(mktemp -d "$RUNNER_TEMP/frame-upgrade.XXXXXX")"
appdir="$fixture/Applications"
mkdir -p "$fixture/tap/Casks" "$appdir"
git init --bare --initial-branch=main "$fixture/origin.git"
git -C "$fixture/tap" init --initial-branch=main
git -C "$fixture/tap" config user.name 'Frame CI'
git -C "$fixture/tap" config user.email frame-ci@example.invalid
git -C "$fixture/tap" config commit.gpgsign false
git -C "$fixture/tap" remote add origin "file://$fixture/origin.git"
cat > "$fixture/tap/Casks/frame.rb" <<'RUBY'
cask "frame" do
  version "3.2.1"
  sha256 "53c3f0b806646cd2eadfc4626aceb78782da709d865e854f9575d4de16fd9175"
  url "https://github.com/tvr-works/frame/releases/download/v#{version}/Frame-v#{version}.zip"
  name "Frame"
  desc "Frame upgrade qualification fixture"
  homepage "https://github.com/tvr-works/frame"
  app "Frame-v#{version}/Frame.app"
  binary "Frame-v#{version}/bin/frame"
end
RUBY
git -C "$fixture/tap" add Casks/frame.rb
git -C "$fixture/tap" commit -m 'Install published legacy layout'
git -C "$fixture/tap" push origin main
brew tap --custom-remote "$tap" "file://$fixture/origin.git"
if brew command trust >/dev/null 2>&1; then brew trust --cask "$brew_ref"; fi
owned_install=false
cleanup() {
    if [[ "$owned_install" == true ]]; then brew uninstall --cask "$brew_ref" || true; fi
}
trap cleanup EXIT
printf 'configuration-preservation-marker\n' > "$fixture/.frame.toml"
config_sha="$(shasum -a 256 "$fixture/.frame.toml")"
echo 'Installing the published 3.2.1 standalone-CLI layout'
owned_install=true
brew install --cask --appdir="$appdir" "$brew_ref"
[[ "$("$prefix/bin/frame" --version)" == 3.2.1+* ]]
[[ -L "$prefix/bin/frame" ]]
legacy_target="$(readlink "$prefix/bin/frame")"
sha="$(shasum -a 256 "$archive" | awk '{print $1}')"
python3 - "$fixture/tap/Casks/frame.rb" "$version" "$archive" "$sha" <<'PY'
from pathlib import Path
import sys
path, version, archive, sha = sys.argv[1:]
Path(path).write_text('''cask "frame" do
  version "%s"
  sha256 "%s"
  url "%s"
  name "Frame"
  desc "Frame upgrade qualification fixture"
  homepage "https://github.com/tvr-works/frame"
  app "Frame-v#{version}/Frame.app"
  binary "#{appdir}/Frame.app/Contents/MacOS/frame", target: "frame"
end
''' % (version, sha, Path(archive).as_uri()))
PY
git -C "$fixture/tap" add Casks/frame.rb
git -C "$fixture/tap" commit -m 'Upgrade to embedded CLI layout'
git -C "$fixture/tap" push origin main
brew update
echo 'Upgrading normally without uninstall/reinstall'
brew upgrade --cask --appdir="$appdir" "$brew_ref"
expected="$version+$(git rev-parse --short HEAD)"
[[ "$("$prefix/bin/frame" --version)" == "$expected" ]]
"$prefix/bin/frame" --help >/dev/null
[[ "$("$appdir/Frame.app/Contents/MacOS/FrameApp" --version)" == "$expected" ]]
[[ -L "$prefix/bin/frame" && "$(readlink "$prefix/bin/frame")" != "$legacy_target" ]]
python3 - "$prefix/bin/frame" "$appdir/Frame.app/Contents/MacOS/frame" <<'PY'
from pathlib import Path
import sys
assert Path(sys.argv[1]).resolve(strict=True) == Path(sys.argv[2]).resolve(strict=True)
PY
receipt="$(find "$(brew --caskroom)/frame" -name INSTALL_RECEIPT.json -type f)"
jq -e --arg tap "$tap" --arg version "$version" \
    '.source.tap == $tap and .source.version == $version' "$receipt" >/dev/null
[[ "$(shasum -a 256 "$fixture/.frame.toml")" == "$config_sha" ]]
codesign --verify --deep --strict "$appdir/Frame.app"
echo 'Upgrade, embedded CLI link, versions, signatures, receipt and configuration marker passed.'
echo 'This ad-hoc CI test does not qualify Gatekeeper or offline first execution.'
brew uninstall --cask "$brew_ref"
owned_install=false
[[ ! -e "$prefix/bin/frame" && ! -L "$prefix/bin/frame" && ! -e "$appdir/Frame.app" ]]
