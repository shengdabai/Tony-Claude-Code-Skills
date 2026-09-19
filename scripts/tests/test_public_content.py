import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'check-public-content.py'
spec = importlib.util.spec_from_file_location('guard', SCRIPT)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
# Synthetic invalid credentials assembled at runtime; never real account material.
SYNTHETIC = 'LTA' + 'I' + 'abc123DEF456ghi789JKL012'
SECRET = 'abc123' + 'DEF456' + 'ghi789' + 'JKL012' + 'mno345'


class ContentRules(unittest.TestCase):
    def test_vendor_key(self):
        self.assertIn('alibaba-access-key-id', guard.findings(SYNTHETIC.encode()))

    def test_json_escaped_multiline_secret(self):
        data = json.dumps({'message': 'AccessKey Secret\n' + SECRET}).encode()
        self.assertIn('labelled-access-key-secret', guard.findings(data))

    def test_plain_multiline_secret(self):
        self.assertIn('labelled-access-key-secret', guard.findings(('AccessKey Secret\n' + SECRET).encode()))

    def test_common_formats(self):
        for value in ['ID:\\t' + SYNTHETIC, '_' + SYNTHETIC,
                      '**AccessKey Secret**: ' + SECRET,
                      'AccessKey Secret：' + SECRET,
                      '| AccessKey Secret | ' + SECRET + ' |']:
            self.assertTrue(guard.findings(value.encode()), value[:20])
        self.assertTrue(guard.findings(SYNTHETIC.encode('utf-16')))

    def test_placeholders(self):
        self.assertEqual([], guard.findings(b'AccessKey Secret: YOUR_ACCESS_KEY_SECRET'))
        self.assertEqual([], guard.findings(('LTA' + 'I' + 'x' * 20).encode()))

    def test_private_paths(self):
        for name in ['sessions_extracted.json', 'nested/sessions_extracted.json',
                     'x/browser_state/state.json', 'x/sessions/export.jsonl',
                     'x/auth.json', 'x/credentials.json', 'SESSIONS_EXTRACTED.JSON', 'Sessions/export.json', 'AI-Archive/export.json', 'ai-archive/export.json', 'AI-Archive/.env.example']:
            self.assertTrue(guard.forbidden_path(name), name)
        self.assertFalse(guard.forbidden_path('scripts/extract_sessions.py'))


class GitSnapshot(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        self.git('init', '-q')

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.repo, check=True, capture_output=True)

    def scan(self):
        return subprocess.run([sys.executable, str(SCRIPT)], cwd=self.repo,
                              capture_output=True, text=True)

    def test_new_staged_file_and_dirty_worktree(self):
        name = 'tests/fixtures/file with\nnewline.txt'
        p = self.repo / name
        p.parent.mkdir(parents=True)
        p.write_text(SYNTHETIC)
        self.git('add', '--', name)
        p.write_text('clean working copy')
        result = self.scan()
        self.assertEqual(1, result.returncode)
        self.assertIn('alibaba-access-key-id', result.stdout)
        self.assertNotIn(SYNTHETIC, result.stdout + result.stderr)
        self.assertEqual(name, json.loads(result.stdout.splitlines()[0])['path'])

    def test_protected_export_fails_without_content_match(self):
        (self.repo / 'sessions_extracted.json').write_text('[]')
        self.git('add', 'sessions_extracted.json')
        self.assertEqual(1, self.scan().returncode)

    def test_env_template_is_scanned(self):
        (self.repo / '.env.example').write_text(SYNTHETIC)
        self.git('add', '.env.example')
        result = self.scan()
        self.assertEqual(1, result.returncode)
        self.assertIn('alibaba-access-key-id', result.stdout)
        self.assertNotIn(SYNTHETIC, result.stdout)

    def test_runtime_example_is_forbidden(self):
        (self.repo / 'sessions').mkdir()
        (self.repo / 'sessions/export.example').write_text('[]')
        self.git('add', 'sessions')
        self.assertEqual(1, self.scan().returncode)

    def test_archive_paths_are_rejected(self):
        folder = self.repo / 'AI-Archive'
        folder.mkdir()
        (folder / 'export.json').write_text('[]')
        (folder / '.env.example').write_text('EXAMPLE=placeholder')
        self.git('add', 'AI-Archive')
        result = self.scan()
        self.assertEqual(1, result.returncode)
        self.assertEqual(2, result.stdout.count('private-runtime-or-credential-file'))

    def test_clean(self):
        (self.repo / 'readme.md').write_text('Example documentation')
        self.git('add', 'readme.md')
        self.assertEqual(0, self.scan().returncode)

    def test_git_error_blocks(self):
        with tempfile.TemporaryDirectory() as empty:
            result = subprocess.run([sys.executable, str(SCRIPT)], cwd=empty, capture_output=True)
        self.assertEqual(2, result.returncode)


class SyncGate(unittest.TestCase):
    def test_retired_hook_has_no_git_side_effects(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            repo = home / 'Desktop/01-项目开发/01-Claude生态/Tony-Claude-Code-Skills'
            repo.mkdir(parents=True)
            real_git = shutil.which('git')
            subprocess.run([real_git, 'init', '-q', str(repo)], check=True)
            (repo / 'scripts').mkdir()
            shutil.copyfile(SCRIPT, repo / 'scripts/check-public-content.py')
            (repo / '.gitignore').write_text('')
            for args in [('add', '.'), ('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture')]:
                subprocess.run([real_git, *args], cwd=repo, check=True)
            source = home / '.claude/skills/demo'
            source.mkdir(parents=True)
            (source / 'SKILL.md').write_text(SYNTHETIC)
            (repo / 'unrelated.txt').write_text('must stay untracked')
            bin_dir = home / 'bin'
            bin_dir.mkdir()
            wrapper = bin_dir / 'git'
            wrapper.write_text('#!/bin/sh\ncase "$1" in\n pull) exit 0;;\n commit|push) touch "$TEST_PUBLISH_MARKER"; exit 99;;\nesac\nexec "$TEST_REAL_GIT" "$@"\n')
            wrapper.chmod(0o755)
            marker = home / 'published'
            env = dict(os.environ, HOME=str(home), PATH=str(bin_dir) + os.pathsep + os.environ['PATH'],
                       TEST_REAL_GIT=real_git, TEST_PUBLISH_MARKER=str(marker))
            hook = SCRIPT.parents[1] / 'my-config/hooks/sync-skills-to-github.sh'
            result = subprocess.run(['bash', str(hook)], env=env, capture_output=True, text=True)
            self.assertEqual(0, result.returncode)
            self.assertEqual('', result.stdout)
            self.assertNotIn(SYNTHETIC, result.stdout + result.stderr)
            self.assertFalse(marker.exists(), 'publication action was reached')
            tracked = subprocess.check_output([real_git, 'ls-files'], cwd=repo).decode()
            self.assertNotIn('unrelated.txt', tracked)
            self.assertNotIn('skills/demo/SKILL.md', tracked)


if __name__ == '__main__':
    unittest.main()
