"""Step definitions for the ephemeral test cluster + hermetic test env (issue #35).

`@offline` scenarios assert the wiring (mise tool/tasks, the `test` helmfile env, the trivial
chart) via file/TOML inspection — no cluster. `@online` scenarios drive a real disposable cluster
(kind, podman) and the `test` environment; they **skip** cleanly when the tooling/cluster is not
available and **refuse** to run against any `homelab-<env>` context.
"""

from __future__ import annotations

import shutil
import subprocess
import tomllib
from pathlib import Path

import pytest
from pytest_bdd import given, parsers, scenarios, then, when

scenarios("ephemeral_test_cluster.feature")

REPO_ROOT = Path(__file__).resolve().parents[2]
TEST_CONTEXT = "kind-homelab-test"
TEST_CLUSTER = "homelab-test"


# ── Online helpers (shared shape with the isolated-tool online steps) ────────────

def _current_context() -> str:
    r = subprocess.run(["kubectl", "config", "current-context"],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def _context_reachable(ctx: str) -> bool:
    r = subprocess.run(["kubectl", "--context", ctx, "get", "--raw", "/readyz"],
                       capture_output=True, text=True)
    return r.returncode == 0


def _is_homelab_context(ctx: str) -> bool:
    """True for the real ``homelab-<env>`` contexts the @online guard must refuse.

    The disposable test context (``kind-homelab-test``) is deliberately NOT named
    ``homelab-*``, so this stays a simple blanket check that can never confuse the
    throwaway cluster with the real dev/prod clusters (see spec FR-012).
    """
    return ctx.startswith("homelab-")


def _require_test_cluster() -> None:
    """Skip cleanly unless a reachable, non-homelab test cluster is present.

    @online scenarios never create the cluster themselves — the ``verify:online``
    task owns the up/down lifecycle. Here we only guard: refuse any homelab context
    and skip when the dedicated test context is not reachable (spec FR-008).
    """
    if shutil.which("kubectl") is None:
        pytest.skip("kubectl not available")
    ctx = _current_context()
    if _is_homelab_context(ctx):
        pytest.skip(f"refusing to run @online against homelab context {ctx!r}")
    if not _context_reachable(TEST_CONTEXT):
        pytest.skip(f"{TEST_CONTEXT!r} not reachable; run 'mise run verify:online'")


# ── Repo-root fixture + generic file/task assertions (offline wiring) ─────────────

@given("the repository root", target_fixture="repo_root")
def repo_root() -> Path:
    return REPO_ROOT


@then(parsers.parse('the file "{rel}" exists'))
def file_exists(repo_root: Path, rel: str) -> None:
    assert (repo_root / rel).is_file(), f"expected file {rel} to exist"


@then(parsers.parse('the file "{rel}" contains "{needle}"'))
def file_contains(repo_root: Path, rel: str, needle: str) -> None:
    text = (repo_root / rel).read_text(encoding="utf-8")
    assert needle in text, f"expected {rel} to contain {needle!r}"


@then(parsers.parse('the mise task "{task}" runs "{command}"'))
def mise_task_runs(repo_root: Path, task: str, command: str) -> None:
    doc = tomllib.loads((repo_root / ".mise.toml").read_text(encoding="utf-8"))
    tasks = doc.get("tasks", {})
    assert task in tasks, f"expected a [tasks.{task!r}] entry in .mise.toml"
    assert command in tasks[task].get("run", ""), f"expected {task!r} to run {command!r}"


# ── Safety guard (offline): @online must never act on a real homelab cluster ──────

@then(parsers.parse('the online cluster guard "{verdict}" the "{ctx}" context'))
def online_guard_verdict(verdict: str, ctx: str) -> None:
    refused = _is_homelab_context(ctx)
    if verdict == "refuses":
        assert refused, f"the @online guard MUST refuse the homelab context {ctx!r}"
    elif verdict == "allows":
        assert not refused, f"the @online guard MUST allow the test context {ctx!r}"
    else:
        raise AssertionError(f"unknown verdict {verdict!r} (use 'refuses' or 'allows')")


# ── Online: a reachable test cluster (its lifecycle is owned by verify:online) ─────

@given("a reachable test cluster", target_fixture="online_ctx")
def reachable_test_cluster() -> dict:
    _require_test_cluster()
    return {"before_context": _current_context()}


@then(parsers.parse('the "{ctx}" context is reachable'))
def context_reachable(online_ctx, ctx: str) -> None:  # pragma: no cover - online only
    assert _context_reachable(ctx), f"{ctx!r} not reachable"


@then("no homelab context was modified")
def no_homelab_touched(online_ctx) -> None:  # pragma: no cover - online only
    # The active context must never be a real homelab context during @online runs.
    assert not _is_homelab_context(_current_context())


@when("I sync the test environment")
def sync_test_env(online_ctx) -> None:  # pragma: no cover - online only
    r = subprocess.run(
        ["helmfile", "-f", str(REPO_ROOT / "helmfile.yaml.gotmpl"), "-e", "test",
         "sync", "--skip-deps"],
        cwd=str(REPO_ROOT), capture_output=True, text=True,
    )
    online_ctx["output"] = r.stdout + r.stderr
    assert r.returncode == 0, online_ctx["output"]


@then("at least two test releases are deployed")
def two_test_releases(online_ctx) -> None:  # pragma: no cover - online only
    import json
    r = subprocess.run(
        ["helm", "list", "-A", "--kube-context", TEST_CONTEXT, "--output", "json"],
        capture_output=True, text=True,
    )
    releases = json.loads(r.stdout or "[]")
    assert len(releases) >= 2, f"expected >=2 test releases, got: {releases!r}"
