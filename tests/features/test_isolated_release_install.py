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


@then(parsers.parse('the sync targeted kube context "{ctx}"'))
def sync_targeted_context(harness, ctx: str) -> None:
    # The sync command must carry an explicit --kube-context so it never relies on
    # the active current-context (helmfile ignores environments.<env>.kubeContext).
    assert f"--kube-context {ctx}" in harness.synced, \
        f"expected the sync to pass --kube-context {ctx!r}; sync args were: {harness.synced!r}"


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


# ── Online steps (real; run against the disposable kind-homelab-test cluster) ────
# Deselected by `-m offline`. They skip cleanly with no test cluster and refuse to
# run against any homelab-<env> context, so they can never touch dev/prod. Mirrors
# the isolated-release-delete online steps (specs/002) and the ephemeral test
# cluster harness (issue #35).

import shutil  # noqa: E402

TEST_CONTEXT = "kind-homelab-test"
TEST_NS = "test"
TARGET = "test-a"   # defined in helmfile/releases/900-test — installed by the test
SIBLING = "test-b"  # its sibling — must be left untouched by an isolated install


def _current_context() -> str:
    r = subprocess.run(["kubectl", "config", "current-context"], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def _test_releases() -> dict[str, dict]:
    """name -> helm release record, for everything in the test namespace."""
    r = subprocess.run(
        ["helm", "list", "-A", "--kube-context", TEST_CONTEXT, "--output", "json"],
        capture_output=True, text=True,
    )
    return {x["name"]: x for x in json.loads(r.stdout or "[]")}


def _require_test_cluster() -> None:
    if shutil.which("kubectl") is None or shutil.which("helm") is None:
        pytest.skip("kubectl/helm not available")
    if _current_context().startswith("homelab-"):
        pytest.skip(f"refusing @online against homelab context {_current_context()!r}")
    r = subprocess.run(["kubectl", "--context", TEST_CONTEXT, "get", "--raw", "/readyz"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        pytest.skip(f"{TEST_CONTEXT!r} not reachable; run 'mise run cluster:test:up'")


@given("a reachable test cluster with only the sibling release deployed",
       target_fixture="online_ctx")
def online_cluster() -> dict:
    _require_test_cluster()
    # Bring both test releases up and Ready, then remove the target so install:one
    # performs a genuine INSTALL (not an update). The sibling stays deployed; we
    # record its helm revision to later prove an isolated install never touched it.
    subprocess.run(
        ["helmfile", "-f", str(REPO_ROOT / "helmfile.yaml.gotmpl"), "-e", "test",
         "sync", "--skip-deps", "--wait"],
        cwd=str(REPO_ROOT), capture_output=True, text=True,
    )
    subprocess.run(
        ["helm", "uninstall", TARGET, "-n", TEST_NS, "--kube-context", TEST_CONTEXT,
         "--wait"],
        capture_output=True, text=True,
    )  # ignore result: the target may already be absent
    releases = _test_releases()
    if SIBLING not in releases:
        pytest.skip(f"sibling {SIBLING!r} not deployed; run 'mise run verify:online'")
    assert TARGET not in releases, f"{TARGET!r} should be absent before an install test"
    return {"sibling_revision": releases[SIBLING]["revision"]}


@when("I install the missing release with install:one")
def online_install(online_ctx) -> None:  # pragma: no cover - online only
    r = subprocess.run(["bash", str(SCRIPT), "test", TARGET, "--yes"],
                       cwd=str(REPO_ROOT), capture_output=True, text=True)
    online_ctx["output"] = r.stdout + r.stderr
    assert r.returncode == 0, online_ctx["output"]


@then("that release is present at the defined version")
def online_release_present(online_ctx) -> None:  # pragma: no cover - online only
    rel = _test_releases().get(TARGET)
    assert rel is not None, f"{TARGET!r} was not installed"
    # helm reports the chart as "<name>-<version>"; 900-test pins version 0.1.0.
    assert rel["chart"].endswith("-0.1.0"), f"unexpected chart version: {rel['chart']!r}"


@then("it was installed, not updated")
def online_labelled_install(online_ctx) -> None:  # pragma: no cover - online only
    # The script must have LABELLED the action install (target was undeployed), and
    # a fresh install starts helm history at revision 1 — an update would be >1.
    assert "install" in online_ctx["output"].lower(), \
        f"expected the action to be labelled 'install':\n{online_ctx['output']}"
    rel = _test_releases().get(TARGET)
    assert rel is not None and str(rel["revision"]) == "1", \
        f"expected a fresh install at revision 1, got: {rel!r}"


@then("the sibling release was not re-synced")
def online_sibling_untouched(online_ctx) -> None:  # pragma: no cover - online only
    rel = _test_releases().get(SIBLING)
    assert rel is not None, f"sibling {SIBLING!r} disappeared — it must stay deployed"
    assert str(rel["revision"]) == str(online_ctx["sibling_revision"]), (
        f"sibling {SIBLING!r} revision changed "
        f"({online_ctx['sibling_revision']} -> {rel['revision']}); "
        "an isolated install must NOT re-sync it"
    )


# ── Online: context pinning proven against a real cluster (reproduces the bug) ───
# Uses a COPY of the kubeconfig with current-context unset — the real ~/.kube/config
# is never modified, so it's safe even if the test crashes. On the pre-fix script
# this fails with the localhost:8080 fallback; with --kube-context it passes.

@given("a reachable test cluster and a kubeconfig copy with current-context unset",
       target_fixture="online_ctx")
def broken_kubeconfig(tmp_path) -> dict:  # pragma: no cover - online only
    _require_test_cluster()
    # Put the real cluster in a known-good state first.
    subprocess.run(
        ["helmfile", "-f", str(REPO_ROOT / "helmfile.yaml.gotmpl"), "-e", "test",
         "sync", "--skip-deps", "--wait"],
        cwd=str(REPO_ROOT), capture_output=True, text=True,
    )
    # Copy the merged kubeconfig, then strip current-context from the COPY ONLY. The
    # copy still KNOWS the kind-homelab-test context — it just isn't current — which
    # is exactly the production condition that broke the sync.
    merged = subprocess.run(["kubectl", "config", "view", "--raw"],
                            capture_output=True, text=True, check=True).stdout
    kubeconfig = tmp_path / "kubeconfig-no-current.yaml"
    kubeconfig.write_text(merged, encoding="utf-8")
    subprocess.run(["kubectl", "--kubeconfig", str(kubeconfig), "config", "unset",
                    "current-context"], capture_output=True, text=True, check=True)
    cur = subprocess.run(["kubectl", "--kubeconfig", str(kubeconfig), "config",
                          "current-context"], capture_output=True, text=True)
    assert not cur.stdout.strip(), "the kubeconfig copy must have NO current-context"
    return {"kubeconfig": str(kubeconfig)}


@when("I install a test release with install:one using that kubeconfig")
def online_install_broken_kubeconfig(online_ctx) -> None:  # pragma: no cover - online only
    env = dict(os.environ)
    env["KUBECONFIG"] = online_ctx["kubeconfig"]
    r = subprocess.run(["bash", str(SCRIPT), "test", TARGET, "--yes"],
                       cwd=str(REPO_ROOT), capture_output=True, text=True, env=env)
    online_ctx["output"] = r.stdout + r.stderr
    assert r.returncode == 0, (
        "install:one failed with current-context unset — the sync is not pinned to "
        f"the env context:\n{online_ctx['output']}"
    )


@then("no localhost:8080 fallback occurred")
def online_no_localhost_fallback(online_ctx) -> None:  # pragma: no cover - online only
    assert "localhost:8080" not in online_ctx["output"], (
        "helm fell back to http://localhost:8080 — the env context was not pinned:\n"
        + online_ctx["output"]
    )
