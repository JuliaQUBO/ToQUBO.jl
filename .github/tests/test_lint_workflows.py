"""Exercise queue compatibility without allowing malformed guards through."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("lint_workflows", ROOT / ".github/scripts/lint_workflows.py")
lint = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(lint)


class QueueLintTests(unittest.TestCase):
    def test_valid_queue_preserves_all_other_source(self):
        text = "name: Docs\nconcurrency:\n  group: documentation-publishing\n  cancel-in-progress: false\n  queue: max\njobs:\n  bad-job: {}\n"
        self.assertEqual(lint.lint_input(text), text.replace("  queue: max\n", "\n"))

    def test_wrong_queue_group_or_cancellation_is_rejected(self):
        text = "concurrency:\n  group: documentation-publishing\n  cancel-in-progress: false\n  queue: max\njobs: {}\n"
        for broken in (text.replace("max", "unknown"), text.replace("false", "true"),
                       text.replace("documentation-publishing", "docs-${{ github.ref }}")):
            with self.assertRaises(ValueError):
                lint.lint_input(broken)

    def test_duplicate_keys_and_inline_queues_are_not_hidden(self):
        text = "concurrency:\n  group: documentation-publishing\n  cancel-in-progress: false\n  queue: max\njobs: {}\n"
        duplicate = text.replace("  queue: max", "  queue: invalid\n  queue: max")
        inline = "concurrency: {group: documentation-publishing, cancel-in-progress: false, queue: max}\njobs: {}\n"
        for broken in (duplicate, inline):
            with self.assertRaises(ValueError):
                lint.lint_input(broken)


if __name__ == "__main__":
    unittest.main()
