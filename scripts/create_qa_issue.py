#!/usr/bin/env python3
"""Generate a release QA issue from the committed Markdown catalog and matrix."""

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import json
import os
import posixpath
from pathlib import Path
import re
import subprocess
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


CATALOG = "AppStore/QA/Scenarios.md"
MATRIX = "AppStore/QA/ReleaseChecklist.template.md"
MARKER = "optiuniverse-release-qa"


@dataclass(frozen=True)
class Scenario:
    title: str
    body: str


@dataclass(frozen=True)
class Run:
    scenario_id: str
    title: str
    configuration: str
    group: str
    conditional: bool


def parse_catalog(text):
    scenarios = {}
    setup = []
    for section in re.split(r"(?m)^## ", text)[1:]:
        section_title, _, content = section.partition("\n")
        entries = list(re.finditer(
            r'^<a name="(qa-[a-z-]+)"></a>\n\n### (QA-[A-Z-]+) · ([^\n]+)\n',
            content, re.MULTILINE,
        ))
        preamble = content[:entries[0].start()] if entries else content
        if preamble.strip():
            setup.append(f"### {section_title}\n\n{preamble.strip()}")
        for index, entry in enumerate(entries):
            anchor, scenario_id, title = entry.groups()
            if anchor != scenario_id.lower() or scenario_id in scenarios:
                raise ValueError(f"Duplicate or mismatched scenario ID {scenario_id}")
            end = entries[index + 1].start() if index + 1 < len(entries) else len(content)
            body = content[entry.end():end].strip()
            if not all(part in body for part in ("**Start**", "\n1. ", "**Reset**")):
                raise ValueError(f"Incomplete scenario {scenario_id}")
            scenarios[scenario_id] = Scenario(title, body)
    if len(scenarios) != len(re.findall(r"(?m)^### QA-", text)) or not scenarios:
        raise ValueError("Catalog contains missing or malformed scenario anchors")
    return scenarios, "\n\n".join(setup)


def parse_matrix(text, scenarios):
    runs = []
    group = ""
    for line in text.splitlines():
        if line.startswith("### "):
            group = line[4:]
        if "[QA-" not in line or not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        link = re.fullmatch(r"\[(QA-[A-Z-]+) · ([^\]]+)\]\(([^)]+)\)", cells[0])
        if len(cells) != 4 or not link or not group:
            raise ValueError(f"Malformed matrix row {line}")
        scenario_id, title, target = link.groups()
        if scenario_id not in scenarios or target != f"../QA/Scenarios.md#{scenario_id.lower()}":
            raise ValueError(f"Unknown scenario or broken link for {scenario_id}")
        conditional = group == "Conditional diagnostics"
        if conditional != ("**Run when**" in scenarios[scenario_id].body):
            raise ValueError(f"Incorrect diagnostic group for {scenario_id}")
        if not cells[1] or cells[2] or cells[3]:
            raise ValueError(f"Matrix must contain a configuration and empty results for {scenario_id}")
        configuration = f"DIAG · {cells[1]}" if conditional else cells[1]
        runs.append(Run(scenario_id, title, configuration, group, conditional))
    if {run.scenario_id for run in runs} != set(scenarios):
        raise ValueError("Matrix must cover every catalog scenario")
    identities = [(run.scenario_id, run.configuration) for run in runs]
    if len(identities) != len(set(identities)):
        raise ValueError("Matrix contains duplicate scenario/configuration rows")
    return runs


def absolute_links(text, source_path, repository, sha):
    def replace(match):
        target = match.group(1)
        if re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:|#", target):
            return match.group(0)
        path = posixpath.normpath(posixpath.join(posixpath.dirname(source_path), target))
        return f"](https://github.com/{repository}/blob/{sha}/{path})"
    return re.sub(r"\]\(([^)]+)\)", replace, text)


def render_issue(catalog, matrix, repository, version, build, sha, diagnostics, test=False, release_pr=None):
    scenarios, setup = parse_catalog(catalog)
    runs = parse_matrix(matrix, scenarios)
    available = {run.scenario_id for run in runs if run.conditional}
    unknown = set(diagnostics) - available
    if unknown:
        raise ValueError(f"Unknown diagnostic IDs: {', '.join(sorted(unknown))}")
    metadata = {
        "format": 1, "kind": "test" if test else "release", "version": version,
        "build": build, "sha": sha, "diagnostics": sorted(set(diagnostics)),
    }
    title = f"{'[TEST] ' if test else ''}Release QA · {version} ({build})"
    environment_start = matrix.index("## Test environments\n")
    environment_end = matrix.index("## Results\n", environment_start)
    environments = matrix[environment_start:environment_end].strip()
    sections = [
        f"<!-- {MARKER} {json.dumps(metadata, sort_keys=True)} -->",
        "Demonstration checklist for reviewing the QA automation. All checks start unchecked."
        if test else "Check a box only after the assigned configuration passes every listed check.",
        f"## Candidate\n\n- Version and build — {version} ({build})\n"
        f"- Source commit — https://github.com/{repository}/commit/{sha}\n"
        f"- Catalog and matrix revision — `{sha}`\n"
        f"- Created (UTC) — {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M')}\n"
        f"- Tester(s) —\n- Release PR — {release_pr or ''}\n- Decision and reviewer —",
        environments,
        "A checked box means PASS. Leave failures, blocked runs and unfinished checks unchecked. "
        "Record the affected scenario ID and configuration in Found defects below, with a bug issue "
        "or evidence link. After a fix, repeat the affected run before checking its box. "
        "Reuse a device across roles where appropriate, while recording each configuration's result.",
        "<details>\n<summary>Shared setup and device instructions</summary>\n\n"
        + absolute_links(setup, CATALOG, repository, sha) + "\n\n</details>",
    ]
    group = None
    for run in runs:
        if run.conditional and run.scenario_id not in diagnostics:
            continue
        if run.group != group:
            group = run.group
            sections.append(f"## {group}")
        source = f"https://github.com/{repository}/blob/{sha}/{CATALOG}#{run.scenario_id.lower()}"
        scenario = scenarios[run.scenario_id]
        body = absolute_links(scenario.body, CATALOG, repository, sha)
        sections.append(
            f"- [ ] **{run.scenario_id} · {run.title}** — {run.configuration}\n\n"
            f"<details>\n<summary>Steps and expected results · {run.scenario_id}</summary>\n\n"
            f"Run in **{run.configuration}**, following any step range specified above.\n\n"
            f"{body}\n\n[Source scenario]({source})\n\n</details>"
        )
    omitted = [run for run in runs if run.conditional and run.scenario_id not in diagnostics]
    if omitted:
        sections.append("## Diagnostics outside this run\n\n"
                        "These diagnostics are recorded as N/A for this run. Confirm their triggers "
                        "do not apply before sign-off. If one is needed, correct the selection before "
                        "starting QA or explicitly add its run to this issue.")
        for run in omitted:
            trigger = re.search(r"\*\*Run when\*\* ([^\n]+)", scenarios[run.scenario_id].body).group(1)
            sections.append(f"- **{run.scenario_id}** — {trigger}")
    sections.extend([
        "## Found defects\n\nKeep bug references here so each test checkbox records a manual "
        "retest result. Include the scenario ID, configuration, bug issue, actual result or "
        "blocker, and the retest date and result.\n\n"
        "| Scenario / configuration | Bug issue or evidence | Actual result / blocker | Retest |\n"
        "| --- | --- | --- | --- |\n| | | | |",
        "## Automated evidence and sign-off\n\nLink the build, tests and strict SwiftLint results "
        f"required by [AGENTS.md](https://github.com/{repository}/blob/{sha}/AGENTS.md). "
        "Include ephemeris and review coordinator test results. Record the decision manually "
        "after all required and selected diagnostic checks pass. Record the physical iPhone "
        "rendering result before sign-off.",
    ])
    body = "\n\n".join(sections) + "\n"
    if len(body.encode("utf-8")) > 65_536:
        raise ValueError("Generated issue exceeds the supported 65,536-byte body budget")
    return title, body, metadata


class GitHubClient:
    def __init__(self, repository, token):
        self.base = f"https://api.github.com/repos/{repository}"
        self.token = token

    def request(self, method, path, payload=None):
        data = json.dumps(payload).encode() if payload is not None else None
        request = Request(self.base + path, data=data, method=method, headers={
            "Authorization": f"Bearer {self.token}", "Accept": "application/vnd.github+json",
            "Content-Type": "application/json", "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "OptiUniverse-release-QA",
        })
        try:
            with urlopen(request, timeout=30) as response:
                return json.load(response)
        except HTTPError as error:
            raise ValueError(f"GitHub API returned HTTP {error.code} for {method} {path}") from error
        except URLError as error:
            raise ValueError(f"GitHub API could not be reached: {error.reason}") from error


def ensure_issue(client, title, body, metadata):
    matches = []
    page = 1
    while True:
        issues = client.request("GET", f"/issues?state=all&per_page=100&page={page}")
        for issue in issues:
            if "pull_request" in issue:
                continue
            match = re.search(rf"^<!-- {MARKER} (.+?) -->$", issue.get("body") or "", re.MULTILINE)
            if not match:
                continue
            try:
                existing = json.loads(match.group(1))
            except json.JSONDecodeError as error:
                raise ValueError(f"Malformed QA metadata in issue #{issue['number']}") from error
            if not isinstance(existing, dict):
                raise ValueError(f"Malformed QA metadata in issue #{issue['number']}")
            identity = ("kind", "version", "build")
            if all(existing.get(key) == metadata[key] for key in identity):
                matches.append((issue, existing))
        if len(issues) < 100:
            break
        page += 1
    if len(matches) > 1:
        raise ValueError("Multiple QA issues exist for this version and build. Resolve the duplicates first.")
    if matches:
        issue, existing = matches[0]
        if existing != metadata:
            raise ValueError(f"Issue #{issue['number']} uses a different commit, diagnostic selection "
                             "or metadata format. Use the original parameters or a new build number.")
        return issue
    return client.request("POST", "/issues", {"title": title, "body": body})


def git(*arguments):
    return subprocess.check_output(["git", *arguments], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY"),
                        required=not os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--ref", default="HEAD", help="Committed candidate ref available in this checkout")
    parser.add_argument("--diagnostics", default="", help="Comma-separated conditional scenario IDs")
    parser.add_argument("--test", action="store_true", help="Use a separate demonstration issue identity")
    parser.add_argument("--release-pr", help="URL of the release or implementation pull request")
    parser.add_argument("--dry-run", action="store_true", help="Print the issue body without network access")
    args = parser.parse_args()
    try:
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository):
            raise ValueError("Repository must be owner/name")
        if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,2}", args.version):
            raise ValueError("Version must be a numeric marketing version, such as 1.11")
        if not re.fullmatch(r"[1-9][0-9]*", args.build):
            raise ValueError("Build must be a positive integer without leading zeros")
        pr_pattern = rf"https://github\.com/{re.escape(args.repository)}/pull/[1-9][0-9]*"
        if args.release_pr and not re.fullmatch(pr_pattern, args.release_pr):
            raise ValueError("Release PR must be a pull request URL in the same repository")
        sha = git("rev-parse", "--verify", "--end-of-options", f"{args.ref}^{{commit}}")
        catalog = git("show", f"{sha}:{CATALOG}") + "\n"
        matrix = git("show", f"{sha}:{MATRIX}") + "\n"
        diagnostics = {item.strip() for item in args.diagnostics.split(",") if item.strip()}
        title, body, metadata = render_issue(catalog, matrix, args.repository, args.version,
                                           args.build, sha, diagnostics, args.test, args.release_pr)
        if args.dry_run:
            print(body, end="")
            return
        token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
        if not token:
            raise ValueError("Set GITHUB_TOKEN or GH_TOKEN to create or find the issue")
        client = GitHubClient(args.repository, token)
        client.request("GET", f"/commits/{sha}")
        issue = ensure_issue(client, title, body, metadata)
        print(issue["html_url"])
        if os.environ.get("GITHUB_OUTPUT"):
            with Path(os.environ["GITHUB_OUTPUT"]).open("a") as output:
                output.write(f"issue_url={issue['html_url']}\nissue_number={issue['number']}\n")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"QA issue generation failed: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
