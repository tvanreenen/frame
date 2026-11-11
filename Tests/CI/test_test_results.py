"""Exercise the test-evidence gate's false-green boundaries without running an app."""

from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "script/ci/verify-test-results.py"
TARGETS = ("FrameEngineTests", "FrameMacOSTests", "FrameUITests")


def completed_target(target):
    return (
        f"Test Case '-[{target}.ExampleTest testExample]' passed (0.001 seconds).\n"
        f"Test Suite '{target}.xctest' passed at 2026-11-11.\n"
        "Executed 1 test, with 0 failures (0 unexpected) in 0.001 seconds\n"
    )


class TestExecutionEvidence(unittest.TestCase):
    def check_log(self, text, expected_success):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "swift-tests.log"
            log.write_text(text)
            result = subprocess.run(["python3", str(SCRIPT), str(log)], capture_output=True, text=True)
            self.assertEqual(result.returncode == 0, expected_success, result.stderr)
            self.assertEqual(log.with_suffix(".json").exists(), expected_success)

    def test_requires_all_completed_targets(self):
        self.check_log("".join(map(completed_target, TARGETS)), True)
        self.check_log(completed_target(TARGETS[0]), False)

    def test_rejects_an_empty_test_run(self):
        self.check_log("Test run with 0 tests passed", False)

    def test_rejects_failure_and_skip_even_with_passed_summaries(self):
        complete = "".join(map(completed_target, TARGETS))
        for outcome in ("failed", "skipped"):
            self.check_log(complete + f"Test Case '-[FrameUITests.Other testOther]' {outcome} (0 seconds).\n", False)

    def test_rejects_summary_without_executed_cases(self):
        complete = "".join(map(completed_target, TARGETS))
        self.check_log(complete.replace("Executed 1 test", "Executed 2 tests", 1), False)

    def test_accepts_the_combined_xcode_26_bundle(self):
        cases = "".join(f"Test Case '-[{target}.ExampleTest testExample]' passed (0.001 seconds).\n" for target in TARGETS)
        summary = "Test Suite 'FramePackagePackageTests.xctest' passed at 2026-11-11.\nExecuted 3 tests, with 0 failures (0 unexpected) in 0.001 seconds\n"
        self.check_log(cases + summary, True)
        self.check_log(cases + summary.replace("Executed 3", "Executed 2"), False)


if __name__ == "__main__":
    unittest.main()
