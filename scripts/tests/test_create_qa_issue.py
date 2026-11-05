"""Regression checks for generated coverage and issue creation without network access."""

from pathlib import Path
import json
import re
import subprocess
import sys
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError, URLError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import create_qa_issue as qa


ROOT = Path(__file__).resolve().parents[2]
SHA = "a" * 40


class ChecklistTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = (ROOT / qa.CATALOG).read_text()
        cls.matrix = (ROOT / qa.MATRIX).read_text()

    def render(self, diagnostics=(), **kwargs):
        return qa.render_issue(self.catalog, self.matrix, "llkenny/optiuniverse", "1.11", "29",
                               SHA, diagnostics, **kwargs)

    def test_default_and_complete_matrix_preserve_configuration_coverage(self):
        scenarios, _ = qa.parse_catalog(self.catalog)
        runs = qa.parse_matrix(self.matrix, scenarios)
        self.assertEqual(len(scenarios), 28)
        self.assertEqual(len(runs), 41)
        title, body, metadata = self.render()
        self.assertEqual(title, "Release QA · 1.11 (29)")
        self.assertEqual(body.count("- [ ] **QA-"), 38)
        self.assertEqual(metadata["diagnostics"], [])
        self.assertIn("## Diagnostics outside this run", body)
        diagnostics = {run.scenario_id for run in runs if run.conditional}
        _, full, _ = self.render(diagnostics)
        self.assertEqual(full.count("- [ ] **QA-"), 41)
        self.assertEqual(full.count("<details>"), full.count("</details>"))
        for run in runs:
            self.assertIn(f"- [ ] **{run.scenario_id} · {run.title}** — {run.configuration}", full)
            self.assertIn(scenarios[run.scenario_id].body.splitlines()[0], full)
        self.assertLess(len(full.encode("utf-8")), 65_536)

    def test_single_diagnostic_only_adds_its_checkbox(self):
        _, body, metadata = self.render(["QA-PREVIEW-ERROR"])
        self.assertEqual(body.count("- [ ] **QA-"), 39)
        self.assertIn("- [ ] **QA-PREVIEW-ERROR", body)
        self.assertNotIn("- [ ] **QA-LOAD-ERROR", body)
        self.assertEqual(metadata["diagnostics"], ["QA-PREVIEW-ERROR"])
        with self.assertRaisesRegex(ValueError, "Unknown diagnostic"):
            self.render(["QA-INSTALL"])

    def test_test_issue_identity_and_pull_request_link(self):
        pr = "https://github.com/llkenny/optiuniverse/pull/123"
        title, body, metadata = self.render(test=True, release_pr=pr)
        self.assertTrue(title.startswith("[TEST] "))
        self.assertEqual(metadata["kind"], "test")
        self.assertIn(pr, body)
        self.assertIn("Demonstration checklist", body)
        self.assertNotIn("- [x]", body)

    def test_relative_source_links_are_pinned_and_external_links_survive(self):
        _, body, _ = self.render()
        self.assertIn(f"/blob/{SHA}/README.md#atmosphere-rendering-diagnostics", body)
        self.assertIn(f"/blob/{SHA}/OptiUniverseTests/ReviewRequestCoordinatorTests.swift", body)
        self.assertIn("https://developer.apple.com/", body)
        self.assertNotRegex(body, r"\]\(\.\.?/")
        scenario_links = re.findall(r"\[Source scenario\]\(([^)]+)\)", body)
        self.assertEqual(len(scenario_links), 38)
        self.assertTrue(all(f"/blob/{SHA}/" in link for link in scenario_links))

    def test_shared_prerequisites_and_environment_roles_are_embedded(self):
        _, body, _ = self.render()
        for text in ("## Test environments", "### Run conventions", "### Mission replays",
                     "### Device configurations and resizing", "### Conditional diagnostics",
                     "HW · physical iPhone", "## Found defects"):
            self.assertIn(text, body)

    def test_cli_preview_reads_committed_sources_without_a_token(self):
        result = subprocess.run([
            sys.executable, str(ROOT / "scripts/create_qa_issue.py"),
            "--repository", "llkenny/optiuniverse", "--version", "1.11", "--build", "29",
            "--test", "--dry-run",
        ], cwd=ROOT, text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.count("- [ ] **QA-"), 38)
        metadata = json.loads(result.stdout.splitlines()[0].removeprefix(f"<!-- {qa.MARKER} ").removesuffix(" -->"))
        self.assertEqual(metadata["kind"], "test")
        self.assertRegex(metadata["sha"], "^[a-f0-9]{40}$")

    def test_missing_duplicate_or_malformed_sources_fail_before_creation(self):
        with self.assertRaisesRegex(ValueError, "missing or malformed"):
            qa.parse_catalog(self.catalog.replace('<a name="qa-install"></a>', ""))
        with self.assertRaisesRegex(ValueError, "Duplicate or mismatched"):
            qa.parse_catalog(self.catalog.replace('name="qa-install"', 'name="qa-update"'))
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            qa.parse_catalog(self.catalog.replace("**Start**", "Start", 1))
        scenarios, _ = qa.parse_catalog(self.catalog)
        install = next(line for line in self.matrix.splitlines() if line.startswith("| [QA-INSTALL"))
        with self.assertRaisesRegex(ValueError, "every catalog scenario"):
            qa.parse_matrix(self.matrix.replace(install, ""), scenarios)
        with self.assertRaisesRegex(ValueError, "duplicate scenario/configuration"):
            qa.parse_matrix(self.matrix.replace(install, install + "\n" + install), scenarios)
        with self.assertRaisesRegex(ValueError, "Unknown scenario or broken link"):
            qa.parse_matrix(self.matrix.replace("#qa-install", "#missing"), scenarios)
        with self.assertRaisesRegex(ValueError, "Malformed matrix row"):
            qa.parse_matrix(self.matrix.replace(install, install + " extra |"), scenarios)


class IssueCreationTests(unittest.TestCase):
    def setUp(self):
        self.metadata = {"format": 1, "kind": "release", "version": "1.11", "build": "29",
                         "sha": SHA, "diagnostics": []}
        self.body = f"<!-- {qa.MARKER} {json.dumps(self.metadata)} -->\n- [ ] Check"
        self.issue = {"number": 123, "html_url": "https://github.com/llkenny/optiuniverse/issues/123",
                      "body": self.body, "state": "open"}
        self.client = Mock()

    def ensure(self):
        return qa.ensure_issue(self.client, "Release QA", self.body, self.metadata)

    def test_creates_issue_after_scanning_all_states(self):
        self.client.request.side_effect = [[], self.issue]
        self.assertEqual(self.ensure(), self.issue)
        self.assertEqual(self.client.request.call_args_list[0].args,
                         ("GET", "/issues?state=all&per_page=100&page=1"))
        self.client.request.assert_called_with("POST", "/issues", {"title": "Release QA", "body": self.body})

    def test_rerun_reuses_closed_issue_and_preserves_edits_without_writes(self):
        issue = {**self.issue, "body": "User introduction\n" + self.body.replace("[ ]", "[x]")
                 + "\nUser notes", "state": "closed"}
        self.client.request.return_value = [issue]
        self.assertIs(self.ensure(), issue)
        self.client.request.assert_called_once()

    def test_test_identity_and_pull_requests_do_not_match_release_issue(self):
        demo_body = self.body.replace('"kind": "release"', '"kind": "test"')
        self.client.request.side_effect = [[{**self.issue, "pull_request": {}},
                                            {**self.issue, "body": demo_body}], self.issue]
        self.ensure()
        self.assertEqual(self.client.request.call_args.args[0], "POST")

    def test_paginates_without_using_search_index(self):
        self.client.request.side_effect = [[{"body": "Unrelated issue"}] * 100, [self.issue]]
        self.assertEqual(self.ensure(), self.issue)
        self.client.request.assert_called_with("GET", "/issues?state=all&per_page=100&page=2")

    def test_conflicting_commit_or_diagnostics_and_duplicates_stop_creation(self):
        for field, value in (("sha", "b" * 40), ("diagnostics", ["QA-LOAD-ERROR"])):
            with self.subTest(field=field):
                altered = {**self.metadata, field: value}
                issue = {**self.issue, "body": f"<!-- {qa.MARKER} {json.dumps(altered)} -->"}
                self.client.reset_mock()
                self.client.request.return_value = [issue]
                with self.assertRaisesRegex(ValueError, "different commit"):
                    self.ensure()
                self.client.request.assert_called_once()
        self.client.request.return_value = [self.issue, self.issue]
        with self.assertRaisesRegex(ValueError, "Multiple QA issues"):
            self.ensure()

    def test_invalid_metadata_and_api_failures_do_not_produce_another_issue(self):
        self.client.request.return_value = [{**self.issue, "body": f"<!-- {qa.MARKER} broken -->"}]
        with self.assertRaisesRegex(ValueError, "Malformed QA metadata"):
            self.ensure()
        self.client.request.side_effect = ValueError("GitHub unavailable")
        with self.assertRaisesRegex(ValueError, "GitHub unavailable"):
            self.ensure()

    def test_http_and_network_errors_are_readable_without_token_disclosure(self):
        client = qa.GitHubClient("llkenny/optiuniverse", "test-token-do-not-print")
        for error, text in ((HTTPError("url", 403, "Forbidden", {}, None), "HTTP 403"),
                            (URLError("offline"), "could not be reached")):
            with self.subTest(error=error), patch.object(qa, "urlopen", side_effect=error):
                with self.assertRaises(ValueError) as raised:
                    client.request("GET", "/issues")
                self.assertIn(text, str(raised.exception))
                self.assertNotIn(client.token, str(raised.exception))


if __name__ == "__main__":
    unittest.main()
