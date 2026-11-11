"""Exercise the real package checksum gate, stopping before archive extraction."""

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
ARCHIVE = "Frame-v0.0.0.zip"
PAYLOAD = b"fixture archive bytes\n"
DIGEST = hashlib.sha256(PAYLOAD).hexdigest()
MANIFEST = f"{DIGEST}  {ARCHIVE}\n"


class PackageChecksum(unittest.TestCase):
    def check_manifest(self, manifest, expected_valid, archive=PAYLOAD):
        # Stay under the checkout so the real script can read its Git metadata.
        fixtures = ROOT / ".build/ci-package-tests"
        fixtures.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=fixtures) as directory:
            fixture = Path(directory)
            script = fixture / "script/ci/verify-package.sh"
            script.parent.mkdir(parents=True)
            shutil.copy2(ROOT / "script/ci/verify-package.sh", script)
            dist = fixture / "dist"
            dist.mkdir()
            if archive is not None:
                (dist / ARCHIVE).write_bytes(archive)
            if manifest is not None:
                (dist / "checksums.txt").write_text(manifest)
            (dist / "unrelated.txt").write_bytes(PAYLOAD)

            # Intercept only extraction: hashing and manifest validation are real.
            # No app or platform-specific validation runs in this portable suite.
            bin_dir = fixture / "bin"
            bin_dir.mkdir()
            ditto = bin_dir / "ditto"
            ditto.write_text("#!/usr/bin/env bash\n: > extraction-reached\nexit 73\n")
            ditto.chmod(0o755)
            env = dict(os.environ, PATH=f"{bin_dir}{os.pathsep}{os.environ['PATH']}")
            result = subprocess.run(["bash", str(script)], env=env, capture_output=True, text=True)
            self.assertEqual((fixture / "extraction-reached").exists(), expected_valid, result.stderr)
            if expected_valid:
                self.assertEqual(result.returncode, 73, result.stderr)
            else:
                self.assertNotEqual(result.returncode, 0)
                self.assertNotEqual(result.returncode, 73)

    def test_accepts_the_expected_archive_checksum(self):
        self.check_manifest(MANIFEST, True)

    def test_rejects_an_unrelated_archive_entry(self):
        self.check_manifest(f"{DIGEST}  unrelated.txt\n", False)

    def test_rejects_extra_or_duplicate_entries(self):
        for extra in (MANIFEST, f"{DIGEST}  unrelated.txt\n"):
            with self.subTest(extra=extra):
                self.check_manifest(MANIFEST + extra, False)

    def test_rejects_incorrect_or_malformed_checksums(self):
        for digest in ("0" * 64, "not-a-sha256"):
            with self.subTest(digest=digest):
                self.check_manifest(f"{digest}  {ARCHIVE}\n", False)

    def test_rejects_empty_or_missing_manifests(self):
        for manifest in ("", None):
            with self.subTest(manifest=manifest):
                self.check_manifest(manifest, False)

    def test_rejects_a_missing_archive(self):
        self.check_manifest(MANIFEST, False, archive=None)

    def test_rejects_changed_archive_bytes(self):
        self.check_manifest(MANIFEST, False, archive=b"changed archive bytes\n")


if __name__ == "__main__":
    unittest.main()
