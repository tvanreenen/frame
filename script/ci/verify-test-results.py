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
        summary = re.search(
            r"Test Suite '" + target + r"\.xctest' passed[^\n]*\n\s*"
            r"Executed (\d+) tests?, with 0 failures \(0 unexpected\)", text,
        )
        if not summary or not passed_cases or int(summary[1]) != len(passed_cases):
            parser.error(f"missing, empty, or inconsistent executed tests for {target}")
        counts[target] = len(passed_cases)
    args.log.with_suffix(".json").write_text(json.dumps(counts, indent=2) + "\n")
    print(f"Verified {sum(counts.values())} executed XCTest cases: {counts}")


if __name__ == "__main__":
    main()
