#!/usr/bin/env python3
"""Require Apple's accepted result and log for the exact submitted payload."""

import hashlib
import json
from pathlib import Path
import sys


def verify(result, log, archive):
    if not isinstance(result, dict) or not isinstance(log, dict):
        raise ValueError("Expected JSON objects for the result and service log")
    if result.get("status") != "Accepted" or log.get("status") != "Accepted":
        raise ValueError("Notarization was not accepted")
    if (not isinstance(result.get("id"), str) or not result["id"]
            or result["id"].lower() != str(log.get("jobId", "")).lower()):
        raise ValueError("Notary log belongs to a different submission")
    if log.get("sha256") != hashlib.sha256(archive.read_bytes()).hexdigest():
        raise ValueError("Notary log does not match the submitted archive")
    issues = [] if log.get("issues") is None else log["issues"]
    if not isinstance(issues, list) or any(not isinstance(issue, dict) or issue.get("severity") == "error" for issue in issues):
        raise ValueError("Notary log contains errors")
    print(f"Notarization accepted; {len(issues)} reported issue(s). Review the retained log.")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: verify-notary-result.py <submission.json> <notary-log.json> <submission.zip>")
    try:
        verify(json.loads(Path(sys.argv[1]).read_text()), json.loads(Path(sys.argv[2]).read_text()),
               Path(sys.argv[3]))
    except (ValueError, OSError, TypeError, KeyError) as error:
        sys.exit(f"Invalid notarization evidence: {error}")
