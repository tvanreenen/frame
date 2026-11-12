"""Exercise release trust gates without Apple credentials or a running app."""

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "script/release"
SPEC = importlib.util.spec_from_file_location("notary_result", SCRIPTS / "verify-notary-result.py")
RESULT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RESULT)
JOB = "12345678-1234-1234-1234-123456789abc"


class NotaryEvidence(unittest.TestCase):
    def test_requires_acceptance_for_the_exact_submission_and_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "submission.zip"
            archive.write_bytes(b"submitted payload")
            result = {"id": JOB, "status": "Accepted"}
            log = {"jobId": JOB, "status": "Accepted", "issues": None,
                   "sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}
            RESULT.verify(result, log, archive)
            for change in ({"status": "Invalid"}, {"status": "In Progress"},
                           {"jobId": "another-submission"}, {"sha256": "0" * 64},
                           {"issues": [{"severity": "error"}]}):
                with self.subTest(change=change), self.assertRaises(ValueError):
                    RESULT.verify(result, dict(log, **change), archive)
            with self.assertRaises(ValueError):
                RESULT.verify(dict(result, status="Invalid"), log, archive)
            with self.assertRaises(ValueError):
                RESULT.verify(dict(result, id=""), dict(log, jobId=""), archive)
            with self.assertRaises(ValueError):
                RESULT.verify([], log, archive)
            archive.write_bytes(b"different payload")
            with self.assertRaises(ValueError):
                RESULT.verify(result, log, archive)


class ReleaseTrustGates(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.calls = self.root / "calls.jsonl"
        self.env = dict(os.environ, PATH=f"{self.bin}{os.pathsep}{os.environ['PATH']}",
                        CALLS=str(self.calls), FRAME_NOTARY_PROFILE="fixture-profile")
        self.package = self.root / "Frame-v0.0.0"
        (self.package / "Frame.app").mkdir(parents=True)
        (self.package / "bin").mkdir()
        (self.package / "bin/frame").touch()
        # Model the external tools' interfaces, not Apple's signing/notary
        # implementation. Real universal ad-hoc signatures are checked by CI.
        self.tool("codesign", '''import plistlib
if "--entitlements" in args:
    values = {"com.apple.security.app-sandbox": False}
    if os.environ.get("BAD_ENTITLEMENT"):
        values["com.apple.security.cs.disable-library-validation"] = True
    sys.stdout.buffer.write(plistlib.dumps(values))
elif "-d" in args:
    arch = args[args.index("--arch") + 1]
    print("Identifier=" + ("com.frame.app" if args[-1].endswith(".app") else "frame"))
    print("TeamIdentifier=9Q355KSV85")
    print("Signature=adhoc")
    runtime = "none" if os.environ.get("BAD_RUNTIME") == arch else "adhoc,runtime"
    print("CodeDirectory v=20500 flags=0x10002(" + runtime + ") hashes=1+1")
    if os.environ.get("BAD_TIMESTAMP") != arch:
        print("Timestamp=Nov 11, 2026")
elif "--check-notarization" in args and args[-1].endswith("bin/frame") and os.environ.get("CLI_NOT_NOTARIZED"):
    sys.exit(1)
elif "--check-notarization" in args and args[-1].endswith("bin/frame") and os.environ.get("CLI_TICKET_DELAYED"):
    marker = Path(os.environ["CALLS"]).with_suffix(".ticket-pending")
    if not marker.exists():
        marker.touch()
        sys.exit(1)
''')
        self.tool("ditto", 'Path(args[-1]).write_bytes(b"submitted payload")\n')
        self.tool("spctl", 'sys.exit(int(os.environ.get("ASSESSMENT_FAILURE", "0")))\n')
        self.tool("sleep", 'pass\n')
        self.tool("xcrun", '''import hashlib
job = "12345678-1234-1234-1234-123456789abc"
if args[:2] == ["notarytool", "submit"]:
    print(json.dumps({"id": job, "status": os.environ.get("NOTARY_STATUS", "Accepted")}))
    sys.exit(int(os.environ.get("SUBMIT_FAILURE", "0")))
elif args[:2] == ["notarytool", "log"]:
    archive = Path(args[-1]).parent / "submission.zip"
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if os.environ.get("WRONG_ARCHIVE"):
        digest = "0" * 64
    Path(args[-1]).write_text(json.dumps({"jobId": job, "status": os.environ.get("NOTARY_STATUS", "Accepted"),
                                       "sha256": digest, "issues": None}))
elif args[0] == "stapler":
    sys.exit(int(os.environ.get("STAPLE_FAILURE", "0")))
else:
    sys.exit(1)
''')

    def tool(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env python3\nimport json, os, sys\nfrom pathlib import Path\n"
                        "args = sys.argv[1:]\n"
                        "with open(os.environ['CALLS'], 'a') as log:\n"
                        "    log.write(json.dumps([Path(sys.argv[0]).name, *args]) + '\\n')\n" + body)
        path.chmod(0o755)

    def run_script(self, name, *args, **changes):
        self.calls.unlink(missing_ok=True)
        return subprocess.run(["bash", str(SCRIPTS / name), *map(str, args)],
                              env=dict(self.env, **changes), capture_output=True, text=True)

    def invocations(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()]

    def test_requires_hardened_runtime_and_timestamp_on_both_architectures(self):
        args = ("developer-id", self.package / "Frame.app", self.package / "bin/frame")
        self.assertEqual(self.run_script("verify-signatures.sh", *args).returncode, 0)
        for variable in ("BAD_RUNTIME", "BAD_TIMESTAMP"):
            for arch in ("arm64", "x86_64"):
                with self.subTest(variable=variable, arch=arch):
                    result = self.run_script("verify-signatures.sh", *args, **{variable: arch})
                    self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertNotEqual(self.run_script("verify-signatures.sh", *args, BAD_ENTITLEMENT="1").returncode, 0)

    def test_rejection_timeout_and_wrong_payload_cannot_reach_stapling(self):
        for changes in ({"NOTARY_STATUS": "Invalid"}, {"NOTARY_STATUS": "In Progress", "SUBMIT_FAILURE": "65"}, {"WRONG_ARCHIVE": "1"}):
            with self.subTest(changes=changes):
                result = self.run_script("notarize-package.sh", self.package, self.root / "evidence", **changes)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertTrue((self.root / "evidence/notary-log.json").exists())
                self.assertFalse(any(call[1:2] == ["stapler"] for call in self.invocations()))

    def test_success_staples_and_validates_the_app(self):
        result = self.run_script("notarize-package.sh", self.package, self.root / "evidence")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.invocations()
        submit = next(call for call in calls if call[1:3] == ["notarytool", "submit"])
        self.assertIn("--wait", submit)
        self.assertIn("--keychain-profile", submit)
        self.assertEqual([call[1:3] for call in calls if call[1:2] == ["stapler"]],
                         [["stapler", "staple"], ["stapler", "validate"]])

    def test_final_distribution_requires_the_cli_ticket_and_app_assessment(self):
        result = self.run_script("verify-distribution.sh", self.package)
        self.assertEqual(result.returncode, 0, result.stderr)
        checks = [call for call in self.invocations() if "--check-notarization" in call]
        self.assertEqual({(call[-1], call[call.index("--arch") + 1]) for call in checks},
                         {(str(self.package / path), arch) for path in ("Frame.app", "bin/frame")
                          for arch in ("arm64", "x86_64")})
        for change in ({"CLI_NOT_NOTARIZED": "1"}, {"ASSESSMENT_FAILURE": "1"}, {"STAPLE_FAILURE": "1"}):
            with self.subTest(change=change):
                self.assertNotEqual(self.run_script("verify-distribution.sh", self.package, **change).returncode, 0)

    def test_delayed_cli_ticket_can_recover_but_persistent_failure_is_bounded(self):
        result = self.run_script("verify-distribution.sh", self.package, CLI_TICKET_DELAYED="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum(call[0] == "sleep" for call in self.invocations()), 1)
        result = self.run_script("verify-distribution.sh", self.package, CLI_NOT_NOTARIZED="1")
        self.assertNotEqual(result.returncode, 0)
        calls = self.invocations()
        self.assertEqual(sum(call[0] == "sleep" for call in calls), 5)
        self.assertFalse(any(call[0] == "spctl" for call in calls))

    def test_publication_rejects_ad_hoc_and_missing_notary_profile_early(self):
        for args in (("--codesign-identity", "-"), ()):
            result = self.run_script("release-preflight.sh", "--version", "v3.2.1", *args,
                                     FRAME_NOTARY_PROFILE="")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("ad-hoc validation" if args else "FRAME_NOTARY_PROFILE", result.stderr)
            self.assertFalse(self.calls.exists(), "preflight contacted tools before rejecting invalid publication")


if __name__ == "__main__":
    unittest.main()
