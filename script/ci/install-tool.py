#!/usr/bin/env python3
"""Install one checksum-pinned CI tool without credentials or system changes."""

import argparse
import hashlib
import io
import json
from pathlib import Path
import platform
import tarfile
import urllib.request
import zipfile


def main():
    root = Path(__file__).resolve().parents[2]
    tools = json.loads(Path(__file__).with_name("tools.json").read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tool", choices=tools)
    args = parser.parse_args()
    spec = tools[args.tool]
    if platform.system() != spec["platform"]:
        parser.error(f"{args.tool} is pinned for {spec['platform']}")
    if args.tool == "actionlint" and platform.machine() not in ("x86_64", "AMD64"):
        parser.error("the pinned Linux actionlint binary requires x86_64")

    request = urllib.request.Request(spec["url"], headers={"User-Agent": "frame-ci"})
    with urllib.request.urlopen(request, timeout=60) as response:
        payload = response.read()
    if hashlib.sha256(payload).hexdigest() != spec["sha256"]:
        raise SystemExit(f"SHA-256 mismatch for {args.tool}; refusing to install")

    # Read only the named binary; never extract archive paths or links.
    if spec["url"].endswith(".zip"):
        with zipfile.ZipFile(io.BytesIO(payload)) as archive:
            binary = archive.read(spec["member"])
    else:
        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as archive:
            member = archive.getmember(spec["member"])
            if not member.isfile():
                raise SystemExit("the pinned archive member is not a regular file")
            binary = archive.extractfile(member).read()

    destination = root / ".build/ci-tools/bin" / args.tool
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(binary)
    destination.chmod(0o755)
    print(f"Installed {args.tool} {spec['version']} at {destination}")


if __name__ == "__main__":
    main()
