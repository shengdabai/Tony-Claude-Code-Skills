"""Check documented CRUD calls against template signatures without app imports."""
import ast
import inspect
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
COPIES = (
    "skills/_collections/dot_claude/skills/fastapi-backend",
    "skills/_collections/rghamilton3-dotfiles/dot_claude/skills/fastapi-backend",
    "skills/rghamilton3-dotfiles/dot_claude/skills/fastapi-backend",
)


class FastAPIReferenceTests(unittest.TestCase):
    def test_user_lookup_examples_match_the_template_signature(self):
        for copy in COPIES:
            root = ROOT / copy
            template = ast.parse(
                (root / "assets/project-template/app/crud/crud_user.py").read_text()
            )
            lookup = next(node for node in template.body
                          if isinstance(node, ast.AsyncFunctionDef) and node.name == "get")
            signature = inspect.Signature([
                inspect.Parameter(arg.arg, inspect.Parameter.POSITIONAL_OR_KEYWORD)
                for arg in lookup.args.args
            ])
            for name, expected in (("error_handling.md", 1), ("patterns.md", 2)):
                document = root / "references" / name
                calls = []
                for block in re.findall(r"```python\n(.*?)```", document.read_text(), re.S):
                    if "crud.user.get(" not in block:
                        continue
                    calls.extend(node for node in ast.walk(ast.parse(block))
                                 if isinstance(node, ast.Call)
                                 and ast.unparse(node.func) == "crud.user.get")
                self.assertEqual(len(calls), expected, str(document.relative_to(ROOT)))
                for index, call in enumerate(calls):
                    with self.subTest(copy=copy, document=name, call=index):
                        # Bind the documented arguments; never execute database/config code.
                        signature.bind(*call.args, **{
                            keyword.arg: keyword.value for keyword in call.keywords
                        })


if __name__ == "__main__":
    unittest.main()
