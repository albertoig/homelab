# Phase 0 Research: Isolated delete of a single Helmfile release

All Technical Context unknowns are resolved below. No `NEEDS CLARIFICATION` remain.

## R1 — Source of truth for the selectable set

**Decision**: Build the candidate list from `helmfile -f helmfile.yaml.gotmpl -e <env> list
--output json` and intersect it with `helm list -A --output json` on `namespace/name`.

**Rationale**: The constitution makes Helmfile the source of truth; `helmfile list` enumerates the
releases the repo *defines* for an environment without touching the cluster. `helm list -A` is the
cross-check that a defined release is actually deployed. The intersection is exactly the
"defined-and-deployed" selectable set (FR-002). Deriving candidates from `helm list` alone would
expose unmanaged releases — forbidden by FR-003.

**Alternatives considered**: Parsing `helmfile/releases/*.gotmpl` directly (rejected: re-implements
templating, fragile); using `helm list` as the primary source (rejected: violates FR-003).

## R2 — JSON shapes and keying

**Decision**: `helmfile list --output json` yields objects with at least `name`, `namespace`,
`enabled`, `installed`, `labels`, `chart`, `version`. `helm list -A --output json` yields objects
with `name`, `namespace`, `revision`, `status`, `chart`, `app_version`. Key both as
`namespace/name`, defaulting an empty/absent helmfile namespace to `default` so keys line up.

**Rationale**: A composite `namespace/name` key avoids collisions when the same release name
appears in different namespaces, and matches how `helm` reports installed releases. `jq` does the
intersection without shelling out per release.

**Alternatives considered**: Keying by name only (rejected: ambiguous across namespaces — see R6).

## R3 — Deleting a single release

**Decision**: `helmfile -f helmfile.yaml.gotmpl -e <env> -l name=<release> destroy --skip-deps`.

**Rationale**: Helmfile auto-injects an implicit `name` label equal to the release name, so the
label selector targets one release. `--skip-deps` avoids re-resolving chart dependencies for a
delete. This is the mechanism the issue specifies and keeps deletion within Helmfile (source of
truth) rather than a raw `helm uninstall`.

**Alternatives considered**: `helm uninstall <release> -n <ns>` (rejected: bypasses Helmfile, and
loses the env/values context); `helmfile destroy` without a selector (rejected: env-wide).

## R4 — Detecting dependents (`needs:`)

**Decision**: Best-effort warning computed from `helmfile -e <env> build` piped to
`yq '.releases[] | select((.needs // []) | any(. == $key)) | ...'`, where `$key` is `namespace/name`.

**Rationale**: `helmfile build` emits the fully rendered desired state including each release's
`needs:` normalized to `namespace/name`, which matches our key format. It is advisory only and
must never fail the command (wrapped so errors are swallowed), satisfying FR-008 without blocking.

**Alternatives considered**: Grepping source `.gotmpl` files for `needs:` (rejected: misses
templated/inherited needs and namespace normalization).

## R5 — mise task wiring (env + optional release + flags)

**Decision**: Add `[tasks."destroy:one"]` with a `usage` block declaring an optional
`[environment]` (no hard `choices` requirement so the interactive picker can run when omitted), an
optional `[release]`, and `--dry-run` / `--yes` flags; the `run` line passes the parsed
`usage_*` values through to `./scripts/helm/destroy-one.sh`. The script itself re-derives the
environment through `lib/env.sh` (arg → `ENV` → prompt) for parity with `install`/`destroy`.

**Rationale**: The existing `destroy` task already uses a `usage` block and passes
`${usage_environment}` explicitly, so mise's usage-spec parsing is the established pattern here.
Declaring the flags in `usage` lets `mise run destroy:one dev redis --dry-run` parse cleanly
instead of relying on `--` passthrough. Optional env keeps the interactive flow that `install`
provides via `lib/env.sh`.

**Alternatives considered**: Bare `run` with no usage spec (works for positional args like
`install`, but mise would not cleanly parse `--dry-run`/`--yes` flags); required `<environment>`
with `choices` (rejected: blocks the no-arg interactive picker).

## R6 — Selector ambiguity and reachability edge cases

**Decision**: If a bare release name matches more than one selectable release (same name, different
namespace), the tool lists the matches and asks the operator to qualify with `namespace/name`
rather than guessing. If `helm list -A` fails (cluster unreachable), the tool errors clearly
instead of treating the selectable set as empty.

**Rationale**: Matches FR edge cases and the "make the dangerous path loud" principle. Full
hardening of the `-l name=` match to guarantee a single target is in the spec's deferred scope;
the disambiguation prompt covers the realistic case now.

**Alternatives considered**: Auto-selecting the first match (rejected: could delete the wrong
release); silently treating an unreachable cluster as "nothing deployed" (rejected: misleading).

## R7 — Test strategy (pytest-bdd, offline vs online)

**Decision**: All behavior is verified through **pytest-bdd** under `tests/features/`. The
`.feature` file carries the acceptance scenarios, each tagged exactly one of `@offline` or
`@online`:

- **`@offline`** (run in CI and pre-commit, no cluster): two kinds of steps —
  1. *Wiring/inspection* steps assert the `destroy:one` mise task exists and is shaped like
     `destroy`, and that the shared `scripts/lib/helmfile.sh` helper exists and is sourced by the
     entry script (the guard lives in the lib, not inline).
  2. *Behavioral* steps run the real `scripts/helm/destroy-one.sh` as a subprocess with a
     temporary PATH of stub `helmfile`/`helm`/`gum`/`kubectl` binaries created by the step
     definitions. The stub `helmfile`/`helm` emit canned `list --output json` so the step can
     assert: unmanaged cluster releases are never selectable, by-name selection works,
     `--dry-run` performs no destroy, `--yes` refuses without a release name, and the exact
     `-l name=<release> destroy --skip-deps` invocation is recorded by the stub (which uninstalls
     nothing).
- **`@online`** (local only, needs a `homelab-<env>` cluster): actually delete a throwaway release
  and assert sibling releases survive and no env-wide resources were removed.

**Rationale**: Driving the real script as a subprocess under stubbed tools keeps the destructive
logic fully testable with zero cluster and zero secrets (Principle V), and keeps a single source
of acceptance truth mapped 1:1 to the spec scenarios.

**Alternatives considered**: Mocking at the Python level instead of stub binaries (rejected:
running the real script as a subprocess is closer to how operators invoke it and exercises the
actual Bash).
