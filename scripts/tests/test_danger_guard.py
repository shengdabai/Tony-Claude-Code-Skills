"""danger-guard.sh must block recursive rm of mount roots under /Volumes.

The hook is fed synthetic PreToolUse payloads; nothing is ever deleted.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


HOOK = Path(__file__).resolve().parents[2] / "my-config/hooks/danger-guard.sh"


class DangerGuardVolumesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)

    def run_hook(self, command, extra_paths=None):
        env = {k: v for k, v in os.environ.items()
               if k != "DANGER_GUARD_EXTRA_PATHS"}
        env["HOME"] = str(Path(self.temp.name) / "home")
        if extra_paths is not None:
            env["DANGER_GUARD_EXTRA_PATHS"] = extra_paths
        payload = json.dumps({"tool_input": {"command": command}})
        return subprocess.run(
            ["bash", str(HOOK)], input=payload, env=env,
            capture_output=True, text=True,
        )

    def assertBlocked(self, command, **kwargs):
        result = self.run_hook(command, **kwargs)
        self.assertEqual(result.returncode, 2, f"{command!r}: {result.stderr}")
        self.assertIn("DANGER-GUARD", result.stderr)
        return result

    def assertAllowed(self, command, **kwargs):
        result = self.run_hook(command, **kwargs)
        self.assertEqual(result.returncode, 0, f"{command!r}: {result.stderr}")
        self.assertEqual(result.stderr, "")

    def test_mount_root_is_blocked(self):
        result = self.assertBlocked("rm -rf /Volumes/ExampleDisk")
        self.assertIn("/Volumes/ExampleDisk", result.stderr)

    def test_mount_root_with_trailing_slash_is_blocked(self):
        self.assertBlocked("rm -rf /Volumes/ExampleDisk/")

    def test_recursive_variants_are_blocked(self):
        for command in ("rm -r /Volumes/ExampleDisk",
                        "rm -R /Volumes/ExampleDisk",
                        "rm -fr /Volumes/ExampleDisk",
                        "rm -r -f /Volumes/ExampleDisk/",
                        "sudo rm -rf /Volumes/ExampleDisk",
                        'rm -rf "/Volumes/Example Disk"',
                        "cd /tmp && rm -rf /Volumes/ExampleDisk",
                        "rm -rf /Volumes/*"):
            with self.subTest(command=command):
                self.assertBlocked(command)

    def test_volumes_itself_still_blocked(self):
        self.assertBlocked("rm -rf /Volumes")

    def test_subdirectory_inside_mount_matches_previous_behaviour(self):
        # Before the sanitising regression only the mount root itself was
        # blocked; deleting a folder inside the disk stays allowed.
        self.assertAllowed("rm -rf /Volumes/ExampleDisk/some/subdir")
        self.assertAllowed("rm -rf /Volumes/ExampleDisk/some/subdir/")

    def test_non_recursive_rm_is_allowed(self):
        self.assertAllowed("rm /Volumes/ExampleDisk")

    def test_unrelated_paths_are_allowed(self):
        self.assertAllowed("rm -rf /tmp/example-build")
        self.assertAllowed("ls /Volumes/ExampleDisk")

    def test_extra_paths_are_blocked_exactly(self):
        extra = "/srv/protected:/mnt/backup/"
        self.assertBlocked("rm -rf /mnt/backup", extra_paths=extra)
        self.assertBlocked("rm -rf /mnt/backup/", extra_paths=extra)
        self.assertBlocked("sudo rm -r /srv/protected", extra_paths=extra)
        self.assertAllowed("rm -rf /mnt/backup/old", extra_paths=extra)
        self.assertAllowed("rm -rf /mnt/other", extra_paths=extra)

    def test_empty_extra_paths_do_not_block_everything(self):
        self.assertAllowed("rm -rf /tmp/example-build", extra_paths="")
        self.assertAllowed("rm -rf /tmp/example-build", extra_paths="::")

    def test_hook_has_no_unexpanded_placeholder(self):
        self.assertNotIn("<external-disk>", HOOK.read_text())


if __name__ == "__main__":
    unittest.main()
