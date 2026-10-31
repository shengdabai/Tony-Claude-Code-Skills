"""getnote-mcp's engines.node must not promise a Node version its locked
dependencies refuse (the @hono/node-server ^2.1.3 override needs >=20).
"""
import json
from pathlib import Path
import re
import unittest


PROJECT = Path(__file__).resolve().parents[2] / "my-config/mcp-servers/getnote-mcp"


def minimum_major(spec):
    """Lowest Node major a simple range accepts (>=, ^, ~, x.y.z, ||)."""
    majors = []
    for part in spec.split("||"):
        match = re.search(r"(\d+)", part)
        if match is None:
            return 0
        majors.append(int(match.group(1)))
    return min(majors)


class GetnoteEnginesTests(unittest.TestCase):
    def test_declared_minimum_covers_locked_dependencies(self):
        package = json.loads((PROJECT / "package.json").read_text())
        lock = json.loads((PROJECT / "package-lock.json").read_text())
        declared = minimum_major(package["engines"]["node"])
        self.assertEqual(
            lock["packages"][""].get("engines", {}).get("node"),
            package["engines"]["node"], "lockfile root engines out of sync")
        for name, meta in lock["packages"].items():
            node = (meta.get("engines") or {}).get("node")
            if not name or not node or meta.get("dev") or meta.get("optional"):
                continue
            with self.subTest(package=name.replace("node_modules/", "")):
                self.assertGreaterEqual(declared, minimum_major(node),
                                        f"{name} needs node {node}")

    def test_hono_node_server_requirement(self):
        lock = json.loads((PROJECT / "package-lock.json").read_text())
        hono = lock["packages"]["node_modules/@hono/node-server"]
        self.assertGreaterEqual(minimum_major(hono["engines"]["node"]), 20)
        package = json.loads((PROJECT / "package.json").read_text())
        self.assertEqual(package["engines"]["node"], ">=20")


if __name__ == "__main__":
    unittest.main()
