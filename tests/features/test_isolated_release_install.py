"""Step definitions for the isolated single-release install/update feature (issue #29).

The ``@offline`` scenarios run the real ``scripts/helm/install-one.sh`` as a subprocess with a
temporary ``PATH`` that shadows ``helmfile``/``helm``/``gum``/``kubectl`` with stubs. The stubs
serve canned ``list --output json`` and record any ``sync`` invocation (plus the ``gum spin``
titles) to files, so we can assert the exact selector used and that no full-environment sync ran —
without a cluster and without installing anything. Mirrors the destroy-one harness (specs/002).
"""

from __future__ import annotations

import json
import os
import stat
import subprocess
import tomllib
from pathlib import Path

import pytest
from pytest_bdd import given, parsers, scenarios, then, when

scenarios("isolated_release_install.feature")

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "scripts" / "helm" / "install-one.sh"


# ── Stub harness ────────────────────────────────────────────────────────────────

def _write(path: Path, body: str) -> None:
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)


@pytest.fixture
def harness(tmp_path: Path):
    """Build a sandbox bin dir of stub tools and return a small controller."""
    bindir = tmp_path / "bin"
    bindir.mkdir()
    defined_json = tmp_path / "defined.json"
    cluster_json = tmp_path / "cluster.json"
    sync_log = tmp_path / "sync.log"
    kubectl_log = tmp_path / "kubectl.log"
    choose_log = tmp_path / "choose.log"
    confirm_log = tmp_path / "confirm.log"
    spin_log = tmp_path / "spin.log"

    build_yaml = tmp_path / "build.yaml"

    _write(bindir / "helmfile", f"""#!/usr/bin/env bash
args="$*"
case "$args" in
  *" list "*)   cat "{defined_json}"; exit 0 ;;
  *" build"*)   cat "{build_yaml}" 2>/dev/null || true; exit 0 ;;
  *" sync"*)    echo "$args" >> "{sync_log}"; exit 0 ;;
esac
exit 0
""")

    _write(bindir / "helm", f"""#!/usr/bin/env bash
if [ "$1" = "list" ]; then cat "{cluster_json}"; exit 0; fi
exit 0
""")

    # gum: confirm -> yes (proceed); choose records what it was offered then picks
    # the first line (or cancels with exit 1 when GUM_CHOOSE_CANCEL=1); spin records
    # its --title then runs the wrapped command; everything else echoes its args.
    _write(bindir / "gum", f"""#!/usr/bin/env bash
case "$1" in
  confirm) echo called >> "{confirm_log}"; exit 0 ;;
  choose)  shift
           opts=()
           while [ "$#" -gt 0 ]; do
             case "$1" in --*) shift 2 ;; *) opts+=("$1"); shift ;; esac
           done
           printf '%s\\n' "${{opts[@]}}" > "{choose_log}"
           [ "${{GUM_CHOOSE_CANCEL:-0}}" = "1" ] && exit 1
           head -n1 "{choose_log}" ;;
  spin)    shift
           title=""
           while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
             [ "$1" = "--title" ] && title="$2"
             shift
           done
           shift
           echo "$title" >> "{spin_log}"
           exec "$@" ;;
  *)       shift; echo "$@" ;;
esac
""")

    _write(bindir / "kubectl", f"""#!/usr/bin/env bash
echo "$*" >> "{kubectl_log}"
exit 0
""")

    class Harness:
        def __init__(self) -> None:
            self.result: subprocess.CompletedProcess | None = None

        def set_defined(self, releases: list[dict]) -> None:
            defined_json.write_text(json.dumps(releases), encoding="utf-8")

        def set_cluster(self, releases: list[dict]) -> None:
            cluster_json.write_text(json.dumps(releases), encoding="utf-8")

        def add_dependency(self, dependent: str, target: str) -> None:
            """Make ``dependent`` (namespace/name) declare a needs: on ``target``."""
            dep_ns, dep_name = dependent.split("/", 1)
            build_yaml.write_text(
                "releases:\n"
                f"  - name: {dep_name}\n"
                f"    namespace: {dep_ns}\n"
                "    needs:\n"
                f"      - {target}\n",
                encoding="utf-8",
            )

        def run(self, env_name: str, release: str | None = None,
                choose_cancel: bool = False, dry_run: bool = False,
                assume_yes: bool = False) -> subprocess.CompletedProcess:
            child_env = dict(os.environ)
            child_env["PATH"] = f"{bindir}:{child_env['PATH']}"
            child_env.pop("ENV", None)  # force the env to come from the argument
            if choose_cancel:
                child_env["GUM_CHOOSE_CANCEL"] = "1"
            argv = ["bash", str(SCRIPT), env_name]
            if release is not None:
                argv.append(release)  # omit entirely to trigger the picker
            if dry_run:
                argv.append("--dry-run")
            if assume_yes:
                argv.append("--yes")
            self.result = subprocess.run(
                argv, capture_output=True, text=True, env=child_env, cwd=str(REPO_ROOT),
            )
            return self.result

        @property
        def synced(self) -> str:
            return sync_log.read_text(encoding="utf-8") if sync_log.exists() else ""

        @property
        def kubectl_called(self) -> bool:
            return kubectl_log.exists() and kubectl_log.read_text(encoding="utf-8").strip() != ""

        @property
        def offered(self) -> str:
            return choose_log.read_text(encoding="utf-8") if choose_log.exists() else ""

        @property
        def confirmed(self) -> bool:
            return confirm_log.exists() and confirm_log.read_text(encoding="utf-8").strip() != ""

        @property
        def spun(self) -> str:
            return spin_log.read_text(encoding="utf-8") if spin_log.exists() else ""

        @property
        def output(self) -> str:
            assert self.result is not None
            return self.result.stdout + self.result.stderr

    return Harness()


def _parse_pairs(spec: str) -> list[dict]:
    """'data/redis' and 'web/ghost' -> [{namespace,name,chart,version}, ...]."""
    out = []
    for token in spec.replace("and", " ").replace("'", " ").replace('"', " ").split():
        if "/" in token:
            ns, name = token.split("/", 1)
            out.append({
                "namespace": ns, "name": name,
                "chart": f"repo/{name}", "version": "1.0.0",
            })
    return out


# ── Repo-root fixture + generic file/task assertions (offline wiring) ────────────

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


@then(parsers.parse('the file "{rel}" does not contain "{needle}"'))
def file_not_contains(repo_root: Path, rel: str, needle: str) -> None:
    text = (repo_root / rel).read_text(encoding="utf-8")
    assert needle not in text, f"expected {rel} to NOT contain {needle!r}"


@then(parsers.parse('the mise task "{task}" runs "{command}"'))
def mise_task_runs(repo_root: Path, task: str, command: str) -> None:
    doc = tomllib.loads((repo_root / ".mise.toml").read_text(encoding="utf-8"))
    tasks = doc.get("tasks", {})
    assert task in tasks, f"expected a [tasks.{task!r}] entry in .mise.toml"
    assert command in tasks[task].get("run", ""), f"expected {task!r} to run {command!r}"


# ── Behavioral steps (offline, via the stub harness) ────────────────────────────

@given(parsers.parse('a Helmfile defining {spec}'))
def helmfile_defines(harness, spec: str) -> None:
    harness.set_defined(_parse_pairs(spec))


@given(parsers.parse('the cluster has {spec} deployed'))
def cluster_has(harness, spec: str) -> None:
    harness.set_cluster(_parse_pairs(spec))


@when(parsers.parse('I run install-one for "{env_name}" targeting "{release}"'))
def run_install_one(harness, env_name: str, release: str) -> None:
    harness.run(env_name, release)


@then("the command succeeds")
def command_succeeds(harness) -> None:
    assert harness.result.returncode == 0, harness.output


@then("the command fails")
def command_fails(harness) -> None:
    assert harness.result.returncode != 0, harness.output


@then(parsers.parse('helmfile synced the release with selector "{selector}"'))
def synced_with_selector(harness, selector: str) -> None:
    assert "sync" in harness.synced, f"no sync invoked; output:\n{harness.output}"
    assert selector in harness.synced, f"expected selector {selector!r} in: {harness.synced!r}"


@then(parsers.parse('the sync used "{flag}"'))
def sync_used_flag(harness, flag: str) -> None:
    assert flag in harness.synced, f"expected {flag!r} in: {harness.synced!r}"


@then("nothing was synced")
def nothing_synced(harness) -> None:
    assert harness.synced.strip() == "", f"unexpected sync: {harness.synced!r}"


@then("only one release was synced")
def only_one_synced(harness) -> None:
    assert not harness.kubectl_called, "kubectl was called — no env-wide steps must run"
    lines = [ln for ln in harness.synced.splitlines() if ln.strip()]
    assert len(lines) == 1, f"expected exactly one sync line, got: {lines!r}"


@then(parsers.parse('the output mentions "{needle}"'))
def output_mentions(harness, needle: str) -> None:
    assert needle in harness.output, f"expected {needle!r} in output:\n{harness.output}"


@then(parsers.parse('a loading spinner titled "{phrase}" was shown'))
def spinner_shown(harness, phrase: str) -> None:
    assert phrase in harness.spun, (
        f"expected a gum spin titled containing {phrase!r}; spinners shown:\n{harness.spun!r}"
    )


# ── User Story 2 — interactive picker ────────────────────────────────────────────

@when(parsers.parse('I run install-one for "{env_name}" with no release'))
def run_no_release(harness, env_name: str) -> None:
    harness.run(env_name)


@when(parsers.parse('I cancel the picker for "{env_name}"'))
def cancel_picker(harness, env_name: str) -> None:
    harness.run(env_name, choose_cancel=True)


@then(parsers.parse('the picker offered "{key}"'))
def picker_offered(harness, key: str) -> None:
    offered = [ln.strip() for ln in harness.offered.splitlines() if ln.strip()]
    assert any(key in line for line in offered), \
        f"expected a picker option containing {key!r}: {offered!r}"


@then(parsers.parse('the picker did not offer "{key}"'))
def picker_not_offered(harness, key: str) -> None:
    offered = [ln.strip() for ln in harness.offered.splitlines() if ln.strip()]
    assert not any(key in line for line in offered), \
        f"{key!r} must not be selectable, but picker offered: {offered!r}"


@then(parsers.parse('the picker offered a row for "{key}" tagged "{action}"'))
def picker_offered_tagged(harness, key: str, action: str) -> None:
    offered = [ln.strip() for ln in harness.offered.splitlines() if ln.strip()]
    assert any(key in line and f"({action})" in line for line in offered), \
        f"expected a picker row for {key!r} tagged ({action}): {offered!r}"


# ── User Story 3 — dry-run preview + prerequisite warning ────────────────────────

@given(parsers.parse('"{dependent}" declares a needs on "{target}"'))
def declares_needs(harness, dependent: str, target: str) -> None:
    harness.add_dependency(dependent, target)


@when(parsers.parse('I dry-run install-one for "{env_name}" targeting "{release}"'))
def run_dry_run(harness, env_name: str, release: str) -> None:
    harness.run(env_name, release, dry_run=True)


# ── User Story 4 — non-interactive --yes ─────────────────────────────────────────

@when(parsers.parse('I run install-one for "{env_name}" targeting "{release}" with --yes'))
def run_yes(harness, env_name: str, release: str) -> None:
    harness.run(env_name, release, assume_yes=True)


@when(parsers.parse('I run install-one for "{env_name}" with --yes and no release'))
def run_yes_no_release(harness, env_name: str) -> None:
    harness.run(env_name, assume_yes=True)


@then("no confirmation was requested")
def no_confirmation(harness) -> None:
    assert not harness.confirmed, "a confirmation prompt was shown but --yes should skip it"


@then("a confirmation was requested")
def confirmation_requested(harness) -> None:
    assert harness.confirmed, "expected a confirmation prompt (prod must confirm even with --yes)"


# ── Online steps (run locally with a cluster; deselected by -m offline) ──────────

@given(parsers.parse('a reachable "{env_name}" cluster with more than one managed '
                     'release deployed'), target_fixture="online_ctx")
def online_cluster(env_name: str) -> dict:
    pytest.skip("online sync scenario requires a live cluster and a throwaway release")
    return {"env": env_name}


@when("I sync a single throwaway release with install:one")
def online_sync(online_ctx) -> None:  # pragma: no cover - online only
    raise NotImplementedError


@then("that release is present at the defined version")
def online_release_present(online_ctx) -> None:  # pragma: no cover - online only
    raise NotImplementedError


@then("the other managed releases are unchanged")
def online_others_unchanged(online_ctx) -> None:  # pragma: no cover - online only
    raise NotImplementedError
