# Phase 0 Research: Isolated install/update of a single Helmfile release

All Technical Context unknowns are resolved below. No `NEEDS CLARIFICATION` remain.

## R1 — Source of truth for the selectable set

**Decision**: Build the candidate list from `helmfile -f helmfile.yaml.gotmpl -e <env> list
--output json` (every defined release), and cross-check `helm list -A --output json` only to label
each as `install` (absent) or `update` (present).

**Rationale**: The constitution makes Helmfile the source of truth. Unlike the delete counterpart —
where the target must also be deployed — install/update must be able to create a not-yet-deployed
release, so the selectable set is the full defined set (FR-002). The cluster is a cross-check for
the action label only (FR-004), never the source (FR-003).

**Alternatives considered**: Intersecting defined ∩ deployed like destroy-one (rejected: would make
first-time installs impossible); deriving candidates from `helm list` (rejected: violates FR-003).

## R2 — JSON shapes and keying

**Decision**: Reuse the `namespace/name` keying already established in `scripts/lib/helmfile.sh`
(`_hf_jq_key`, empty namespace → `default`). `helmfile_installable_rows` emits `key<TAB>action` per
defined release; `helmfile_cluster_keys` lists installed `namespace/name` for the unmanaged guard.

**Rationale**: A composite key avoids cross-namespace collisions and matches `helm`'s reporting.
Reusing the shared internals keeps both isolated tools consistent (FR-011).

## R3 — Syncing a single release

**Decision**: `helmfile -f helmfile.yaml.gotmpl -e <env> -l name=<release> sync --skip-deps`.

**Rationale**: Helmfile auto-injects an implicit `name` label equal to the release name, so the
label selector targets one release. `--skip-deps` avoids re-resolving chart dependencies. This is
exactly the manual command the issue generalises, and keeps the sync inside Helmfile (source of
truth) rather than a raw `helm upgrade --install`.

**Alternatives considered**: `helm upgrade --install <release> -n <ns>` (rejected: bypasses
Helmfile and loses env/values context); `helmfile sync` without a selector (rejected: env-wide).

## R4 — Prerequisite awareness (`needs:`)

**Decision**: Best-effort warning of the release's OWN `needs:` computed from
`helmfile -e <env> build` piped to `yq`, filtering to the target release and emitting its needs.
Advisory only; never fails the command.

**Rationale**: For install/update the relevant dependency direction is the release's prerequisites
(what it needs), which is the inverse of destroy-one's dependents query. `helmfile build` emits the
rendered desired state with normalized `namespace/name`, matching our key format (FR-009).

**Alternatives considered**: Grepping source `.gotmpl` for `needs:` (rejected: misses
templated/inherited needs and namespace normalization); reusing `helmfile_dependents` (rejected:
wrong direction for install).

## R5 — mise task wiring (env + optional release + flags)

**Decision**: Add `[tasks."install:one"]` with a `usage` block declaring an optional
`[environment]`, an optional `[release]`, and `--dry-run` / `--yes` flags; the `run` line passes the
parsed `usage_*` values through to `./scripts/helm/install-one.sh`. Identical shape to `destroy:one`.

**Rationale**: `destroy:one` already established this usage-spec pattern; mirroring it keeps the two
isolated tools symmetric and lets `mise run install:one dev redis --dry-run` parse cleanly.

## R6 — Selector ambiguity and reachability edge cases

**Decision**: If a bare release name matches more than one selectable release (same name, different
namespace), list the matches and ask the operator to qualify with `namespace/name`. If `helm list
-A` fails (cluster unreachable), error clearly instead of treating the set as empty.

**Rationale**: Matches the "make the dangerous path loud" principle and mirrors destroy-one. Full
hardening of the `-l name=` match is deferred scope shared with #30.

## R7 — Test strategy (pytest-bdd, offline vs online)

**Decision**: All behavior is verified through **pytest-bdd** under `tests/features/`, mirroring the
delete feature. `@offline` scenarios run the real `install-one.sh` under stub
`helmfile`/`helm`/`gum`/`kubectl` binaries: the stub `helmfile` serves canned `list`/`build` output
and records the `sync` argv; the stub `gum` records `spin` titles and picks the first `choose`
option. `@online` scenarios sync a throwaway release against a `homelab-<env>` cluster and assert
siblings are untouched.

**Rationale**: Running the real script as a subprocess under stubbed tools keeps the logic fully
testable with zero cluster and zero secrets (Principle V) and maps 1:1 to the spec scenarios.
