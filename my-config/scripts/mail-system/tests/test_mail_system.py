import sys
import os
import tempfile
import unittest
from email import message_from_string
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import buffer  # noqa: E402
import mail_agent  # noqa: E402
import mail_client  # noqa: E402
import rules  # noqa: E402
import summarize  # noqa: E402


class RulesTests(unittest.TestCase):
    def test_ai_newsletter_is_focus_even_with_unsubscribe_header(self):
        self.assertEqual(
            rules.classify(
                "Claude Code release notes",
                "Anthropic <news@anthropic.com>",
                True,
            ),
            "focus",
        )

    def test_explicit_sale_is_promo(self):
        self.assertEqual(
            rules.classify("限时 50% OFF", "Deals <promo@example.com>", True),
            "promo",
        )

    def test_security_notice_is_urgent(self):
        self.assertEqual(
            rules.classify("Suspicious sign-in alert", "security@example.com", False),
            "urgent",
        )

    def test_generic_newsletter_is_subscription_not_promo(self):
        self.assertEqual(
            rules.classify("Weekly product digest", "hello@example.com", True),
            "subscription",
        )

    def test_sales_sender_does_not_turn_normal_mail_into_promo(self):
        self.assertEqual(
            rules.classify("Quarterly account review", "sales@example.com", False),
            "info",
        )


class DeduplicationTests(unittest.TestCase):
    def test_same_message_id_keeps_gmail_original_over_qq_forward(self):
        records = [
            {
                "account": "QQ",
                "sender": "AI News <news@example.com>",
                "subject": "Daily AI",
                "snippet": "Model X launched today.",
                "message_id": "<same@example.com>",
                "uid": "11",
            },
            {
                "account": "Gmail",
                "sender": "AI News <news@example.com>",
                "subject": "Daily AI",
                "snippet": "Model X launched today.",
                "message_id": "<same@example.com>",
                "uid": "22",
            },
        ]

        unique, duplicates = buffer.deduplicate(records)

        self.assertEqual([r["account"] for r in unique], ["Gmail"])
        self.assertEqual([r["account"] for r in duplicates], ["QQ"])

    def test_same_content_with_tracking_noise_is_deduplicated(self):
        records = [
            {
                "account": "QQ",
                "sender": "Digest <digest@example.com>",
                "subject": "AI Weekly #42",
                "snippet": "Three important model launches changed agent workflows this week. "
                           "The detailed analysis is available online. user=abc12345",
                "message_id": "<one@example.com>",
                "uid": "1",
            },
            {
                "account": "QQ",
                "sender": "Digest <digest@example.com>",
                "subject": "Re: AI Weekly #42",
                "snippet": "Three important model launches changed agent workflows this week. "
                           "The detailed analysis is available online. user=xyz98765",
                "message_id": "<two@example.com>",
                "uid": "2",
            },
        ]

        unique, duplicates = buffer.deduplicate(records)

        self.assertEqual(len(unique), 1)
        self.assertEqual(len(duplicates), 1)

    def test_duplicate_move_plan_only_targets_suppressed_copy(self):
        records = [
            {"account": "QQ", "uid": "7", "sender": "n@example.com",
             "subject": "News", "snippet": "same", "message_id": "<x>"},
            {"account": "Gmail", "uid": "8", "sender": "n@example.com",
             "subject": "News", "snippet": "same", "message_id": "<x>"},
        ]

        plan = mail_agent.duplicate_move_plan(records)

        self.assertEqual(plan, {"QQ": ["7"]})

    def test_empty_snippets_with_different_ids_are_not_collapsed(self):
        records = [
            {"account": "QQ", "sender": "bank@example.com", "subject": "交易提醒",
             "snippet": "", "message_id": "<one>", "cls": "action"},
            {"account": "QQ", "sender": "bank@example.com", "subject": "交易提醒",
             "snippet": "", "message_id": "<two>", "cls": "action"},
        ]

        unique, duplicates = buffer.deduplicate(records)

        self.assertEqual(len(unique), 2)
        self.assertEqual(duplicates, [])

    def test_same_account_duplicate_id_is_never_moved(self):
        records = [
            {"account": "QQ", "uid": "1", "sender": "n@example.com",
             "subject": "News", "message_id": "<same>"},
            {"account": "QQ", "uid": "2", "sender": "n@example.com",
             "subject": "News", "message_id": "<same>"},
        ]

        self.assertEqual(mail_agent.duplicate_move_plan(records), {})

    def test_cross_account_id_collision_with_different_sender_is_not_moved(self):
        records = [
            {"account": "Gmail", "uid": "1", "sender": "a@example.com",
             "subject": "News", "message_id": "<same>"},
            {"account": "QQ", "uid": "2", "sender": "b@example.com",
             "subject": "News", "message_id": "<same>"},
        ]

        self.assertEqual(mail_agent.duplicate_move_plan(records), {})


class SnippetTests(unittest.TestCase):
    def test_html_snippet_omits_script_and_style_content(self):
        msg = message_from_string(
            "Content-Type: text/html; charset=utf-8\n\n"
            "<style>.secret{display:none}</style><script>ignore()</script>"
            "<h1>Important launch</h1><p>Model X is available.</p>"
        )

        snippet = mail_client._extract_snippet(msg, limit=200)

        self.assertEqual(snippet, "Important launch Model X is available.")

    def test_fetched_message_contains_ids_recipient_and_body_snippet(self):
        raw = (
            b"From: Digest <news@example.com>\r\n"
            b"To: <email-redacted>\r\n"
            b"Subject: AI launch\r\n"
            b"Message-ID: <launch@example.com>\r\n"
            b"Date: Wed, 03 Sep 2026 10:00:00 +0800\r\n"
            b"Content-Type: text/plain; charset=utf-8\r\n\r\n"
            b"The new model is live."
        )

        record = mail_client._parse_fetched_message(b"1 (UID 42)", raw)

        self.assertEqual(record["uid"], "42")
        self.assertEqual(record["message_id"], "<launch@example.com>")
        self.assertEqual(record["recipient"], "<email-redacted>")
        self.assertEqual(record["snippet"], "The new model is live.")


class DigestTests(unittest.TestCase):
    @patch("summarize.summarize_detailed")
    def test_digest_reports_unique_and_suppressed_counts(self, summarize_detailed):
        summarize_detailed.return_value = ("【今日重点】\n- Model X 发布", "GPT-5.6 Sol")
        records = [
            {
                "account": "Gmail",
                "sender": "news@example.com",
                "subject": "Model X",
                "snippet": "Model X launched.",
                "cls": "focus",
            }
        ]

        subject, html, text = mail_agent.build_digest(
            records,
            {"received": 4, "duplicates": 2, "promo": 1},
        )

        self.assertIn("去重后 1 封", subject)
        self.assertIn("重复 2 封", text)
        self.assertIn("广告 1 封", text)
        self.assertIn("GPT-5.6 Sol", html)
        summarize_detailed.assert_called_once()

    def test_render_tolerates_missing_model_fields(self):
        rendered = summarize._render({
            "overview": ["正常"],
            "attention": [{"title": "待办"}],
            "focus": [{"title": "AI 更新"}],
            "other": [],
        })

        self.assertIn("待办", rendered)
        self.assertIn("AI 更新", rendered)

    def test_codex_environment_excludes_mail_credentials(self):
        with patch.dict(os.environ, {
            "QQ_AUTH_CODE": "secret-qq",
            "GMAIL_APP_PASSWORD": "secret-gmail",
            "PATH": "/usr/bin:/bin",
            "HOME": "/tmp/home",
        }, clear=True):
            env = summarize._safe_codex_env()

        self.assertNotIn("QQ_AUTH_CODE", env)
        self.assertNotIn("GMAIL_APP_PASSWORD", env)
        self.assertEqual(env["HOME"], "/tmp/home")


class MoveSafetyTests(unittest.TestCase):
    def test_move_uses_uid_move_without_global_expunge(self):
        class FakeConnection:
            capabilities = (b"IMAP4REV1", b"MOVE", b"UIDPLUS")

            def __init__(self):
                self.calls = []

            def select(self, folder):
                self.calls.append(("select", folder))
                return "OK", []

            def uid(self, command, *args):
                self.calls.append(("uid", command, *args))
                return "OK", [b""]

            def expunge(self):
                raise AssertionError("global expunge must never be called")

        mailbox = mail_client.MailBox({"name": "QQ"})
        mailbox.conn = FakeConnection()
        mailbox.trash_folder = "Deleted Messages"

        moved = mailbox.move_to_trash(["10", "11"])

        self.assertEqual(moved, 2)
        self.assertIn(
            ("uid", "MOVE", "10,11", '"Deleted Messages"'),
            mailbox.conn.calls,
        )


class BufferSafetyTests(unittest.TestCase):
    def test_buffer_is_private_after_append(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "digest.jsonl"
            with patch.object(buffer, "BUFFER", target), \
                    patch.object(buffer, "LOCK_FILE", Path(tmp) / ".lock"):
                buffer.append("QQ", [{"sender": "a", "subject": "b"}])

            self.assertEqual(target.stat().st_mode & 0o777, 0o600)

    @patch("mail_agent.buffer.append", side_effect=OSError("disk full"))
    def test_buffer_failure_does_not_change_mail_state(self, _append):
        calls = []

        class FakeMailbox:
            def __init__(self, account):
                pass

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return None

            def fetch_unseen(self):
                return [{"uid": "1", "sender": "a@example.com", "subject": "Hello",
                         "snippet": "body", "message_id": "<x>",
                         "has_list_unsub": False, "is_system_digest": False}]

            def mark_seen(self, uids):
                calls.append(("seen", uids))
                return len(uids)

            def move_to_trash(self, uids):
                calls.append(("trash", uids))
                return len(uids)

        account = {"name": "QQ", "email": "reader@example.com"}
        with patch("mail_agent.MailBox", FakeMailbox):
            result = mail_agent.process_account(account, dry_run=False)

        self.assertIn("disk full", result["error"])
        self.assertEqual(calls, [])


if __name__ == "__main__":
    unittest.main()
