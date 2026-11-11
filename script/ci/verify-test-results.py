#!/usr/bin/env python3
"""Require nonempty, completed XCTest targets in the Swift test process log."""

import argparse
from pathlib import Path
import json
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    text = args.log.read_text()
    expected = {"FrameEngineTests", "FrameMacOSTests", "FrameUITests"}
    if re.search(r"Test Case .* (failed|skipped) ", text):
        parser.error("a test failed or was unexpectedly skipped")
    counts = {}
    for target in sorted(expected):
        passed_cases = re.findall(r"Test Case '-\[" + target + r"\.[^\]]+\]' passed ", text)
        if not passed_cases:
            parser.error(f"missing executed tests for {target}")
        counts[target] = len(passed_cases)
    # Xcode 26.2 combines targets into one XCTest bundle; newer SwiftPM can split them.
    summaries = re.findall(
        r"Test Suite '[^'\n]+\.xctest' passed[^\n]*\n\s*"
        r"Executed (\d+) tests?, with 0 failures \(0 unexpected\)", text,
    )
    if not summaries or sum(map(int, summaries)) != sum(counts.values()):
        parser.error("missing or inconsistent completed XCTest bundle summaries")
    args.log.with_suffix(".json").write_text(json.dumps(counts, indent=2) + "\n")
    print(f"Verified {sum(counts.values())} executed XCTest cases: {counts}")


if __name__ == "__main__":
    main()
