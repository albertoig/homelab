"""Step definitions for the Spec Kit adoption acceptance feature.

These scenarios are tagged ``@offline``: they only inspect repository files and
the CI workflow definitions, so they run without a cluster in pre-commit and CI.
"""

from __future__ import annotations

import fnmatch
import re
import tomllib
from pathlib import Path

import yaml
from pytest_bdd import given, parsers, scenarios, then

# Bind every scenario in the feature file (resolved via bdd_features_base_dir).
scenarios("spec_kit_adoption.feature")

REPO_ROOT = Path(__file__).resolve().parents[2]


# ── Given ──────────────────────────────────────────────────────────────────────

@given("the repository root", target_fixture="repo_root")
def repo_root() -> Path:
    return REPO_ROOT


# ── File / directory assertions ────────────────────────────────────────────────

@then(parsers.parse('the directory "{rel}" exists'))
def directory_exists(repo_root: Path, rel: str) -> None:
    path = repo_root / rel
    assert path.is_dir(), f"expected directory {rel} to exist"


@then(parsers.parse('the file "{rel}" exists'))
def file_exists(repo_root: Path, rel: str) -> None:
    path = repo_root / rel
    assert path.is_file(), f"expected file {rel} to exist"


@then(parsers.parse('the file "{rel}" contains "{needle}"'))
def file_contains(repo_root: Path, rel: str, needle: str) -> None:
    path = repo_root / rel
    text = path.read_text(encoding="utf-8")
    assert needle in text, f"expected {rel} to contain {needle!r}"


@then(parsers.parse('the file "{rel}" does not contain "{needle}"'))
def file_not_contains(repo_root: Path, rel: str, needle: str) -> None:
    path = repo_root / rel
    text = path.read_text(encoding="utf-8")
    assert needle not in text, f"expected {rel} to NOT contain {needle!r}"


# ── mise task assertions (offline/online split) ────────────────────────────────

def _mise_task_run(repo_root: Path, task: str) -> str:
    doc = tomllib.loads((repo_root / ".mise.toml").read_text(encoding="utf-8"))
    tasks = doc.get("tasks", {})
    assert task in tasks, f"expected a [tasks.{task!r}] entry in .mise.toml"
    run = tasks[task].get("run", "")
    assert run, f"expected task {task!r} to define a `run` command"
    return run


@then('"mise run verify" runs both offline and online scenarios')
def verify_runs_both(repo_root: Path) -> None:
    run = _mise_task_run(repo_root, "verify")
    assert "offline" in run and "online" in run, (
        "`verify` should run both tags, e.g. pytest -m 'offline or online'"
    )


@then('"mise run verify:offline" runs only offline scenarios')
def verify_offline_runs_offline_only(repo_root: Path) -> None:
    run = _mise_task_run(repo_root, "verify:offline")
    assert "offline" in run, "`verify:offline` should select the offline marker"
    assert "online" not in run, "`verify:offline` must NOT run online scenarios"


# ── CI enforcement assertions ──────────────────────────────────────────────────

# Markers that identify a job step as running the offline BDD verification.
_BDD_RUN_MARKERS = ("verify:offline", "run verify", "test:bdd")

# A run-step is "online" if it selects the online marker or runs the full `verify`
# task (bare `mise run verify`, which includes @online and needs a cluster).
_ONLINE_RUN_PATTERNS = (
    re.compile(r"-m\s+['\"]?(?:online|offline or online|online or offline)"),
    re.compile(r"mise run verify(?!:offline)"),
)


def _push_triggers_branch(on: object, branch: str) -> bool:
    """Return True if a ``push`` to ``branch`` triggers a workflow with this ``on``."""
    # ``on`` can be a string ("push"), a list (["push", ...]) or a mapping.
    if on == "push":
        return True
    if isinstance(on, list):
        return "push" in on
    if not isinstance(on, dict) or "push" not in on:
        return False

    push = on["push"]
    if not isinstance(push, dict):
        # ``push:`` with no filters → every branch.
        return True

    branches = push.get("branches")
    if branches is not None:
        return any(fnmatch.fnmatch(branch, pat) for pat in branches)

    ignore = push.get("branches-ignore")
    if ignore is not None:
        return not any(fnmatch.fnmatch(branch, pat) for pat in ignore)

    # ``push:`` present but neither filter → every branch.
    return True


def _load_workflow(repo_root: Path, name: str) -> dict:
    path = repo_root / ".github" / "workflows" / name
    if not path.is_file():
        return {}
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def _workflow_runs_bdd(doc: dict, repo_root: Path, _seen: set[str] | None = None) -> bool:
    """True if the workflow runs the offline BDD verification.

    Follows ``uses: ./.github/workflows/<file>`` reusable-workflow references one or
    more levels deep, so release.yml → validate.yml counts as running BDD.
    """
    _seen = _seen or set()
    for job in (doc.get("jobs") or {}).values():
        for step in job.get("steps") or []:
            run = step.get("run") or ""
            if any(marker in run for marker in _BDD_RUN_MARKERS):
                return True
        uses = job.get("uses")
        if isinstance(uses, str) and uses.startswith("./.github/workflows/"):
            ref = uses.split("/")[-1].split("@")[0]
            if ref not in _seen:
                _seen.add(ref)
                if _workflow_runs_bdd(_load_workflow(repo_root, ref), repo_root, _seen):
                    return True
    return False


def _iter_run_steps(repo_root: Path):
    """Yield (workflow_name, run_string) for every run-step in every workflow."""
    workflows_dir = repo_root / ".github" / "workflows"
    for wf in sorted(workflows_dir.glob("*.y*ml")):
        doc = yaml.safe_load(wf.read_text(encoding="utf-8")) or {}
        for job in (doc.get("jobs") or {}).values():
            for step in job.get("steps") or []:
                run = step.get("run")
                if run:
                    yield wf.name, run


@then(parsers.parse('a CI workflow runs the offline BDD verification on a push to "{branch}"'))
def ci_enforces_offline_bdd(repo_root: Path, branch: str) -> None:
    workflows_dir = repo_root / ".github" / "workflows"
    matches: list[str] = []
    for wf in sorted(workflows_dir.glob("*.y*ml")):
        doc = yaml.safe_load(wf.read_text(encoding="utf-8")) or {}
        # PyYAML parses the bare ``on:`` key as the boolean True.
        on = doc.get("on", doc.get(True))
        if _workflow_runs_bdd(doc, repo_root) and _push_triggers_branch(on, branch):
            matches.append(wf.name)
    assert matches, (
        f"no CI workflow runs the offline BDD verification on a push to {branch!r}; "
        "expected a workflow running `mise run verify:offline` that triggers on this branch"
    )


@then(parsers.parse('a CI workflow runs "{command}"'))
def ci_runs_command(repo_root: Path, command: str) -> None:
    hits = [wf for wf, run in _iter_run_steps(repo_root) if command in run]
    assert hits, f"expected a CI workflow step to run {command!r}"


@then("no CI workflow runs online scenarios")
def ci_runs_no_online(repo_root: Path) -> None:
    offenders = [
        f"{wf}: {run.strip()!r}"
        for wf, run in _iter_run_steps(repo_root)
        if any(pat.search(run) for pat in _ONLINE_RUN_PATTERNS)
    ]
    assert not offenders, (
        "CI must run offline scenarios only, but these steps run online ones: "
        + "; ".join(offenders)
    )
