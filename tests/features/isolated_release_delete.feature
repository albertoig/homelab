Feature: Isolated delete of a single Helmfile release
  As a homelab operator
  I want to delete one Helmfile-managed release by name
  So that I can remove a single component without destroying the whole environment

  # ── User Story 1 (P1) — safe by-name deletion + YAML/cluster guard ────────────

  @offline
  Scenario: The destroy:one task is wired into mise like destroy
    Given the repository root
    Then the mise task "destroy:one" runs "./scripts/helm/destroy-one.sh"
    And the file ".mise.toml" contains "destroy:one"

  @offline
  Scenario: The guard logic lives in the shared library and the script sources it
    Given the repository root
    Then the file "scripts/lib/helmfile.sh" exists
    And the file "scripts/helm/destroy-one.sh" contains "lib/helmfile.sh"
    And the file "scripts/helm/destroy-one.sh" contains "helmfile_selectable_releases"

  @offline
  Scenario: Deleting a managed, deployed release uninstalls only that release
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "data/rogue" deployed
    When I run destroy-one for "dev" targeting "redis"
    Then the command succeeds
    And helmfile destroyed the release with selector "name=redis"
    And the destroy used "--skip-deps"
    And no environment-wide cleanup ran

  @offline
  Scenario: A release running in the cluster but not defined in YAML is refused
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "data/rogue" deployed
    When I run destroy-one for "dev" targeting "rogue"
    Then the command fails
    And nothing was destroyed
    And the output mentions "not a deletable release"

  @offline
  Scenario: A release defined in YAML but not deployed is a no-op
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "data/rogue" deployed
    When I run destroy-one for "dev" targeting "ghost"
    Then the command succeeds
    And nothing was destroyed
    And the output mentions "Nothing to delete"

  # ── User Story 2 (P2) — interactive picker ────────────────────────────────────

  @offline
  Scenario: With no release argument the picker lists only selectable releases
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "web/ghost" and "data/rogue" deployed
    When I run destroy-one for "dev" with no release
    Then the command succeeds
    And the picker offered "data/redis"
    And the picker offered "web/ghost"
    And the picker did not offer "data/rogue"

  @offline
  Scenario: Cancelling the picker deletes nothing
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "web/ghost" deployed
    When I cancel the picker for "dev"
    Then the command succeeds
    And nothing was destroyed

  # ── User Story 3 (P2) — dry-run preview + dependency warning ───────────────────

  @offline
  Scenario: Dry run previews the release and makes no changes
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "web/ghost" deployed
    When I dry-run destroy-one for "dev" targeting "redis"
    Then the command succeeds
    And nothing was destroyed
    And the output mentions "redis"
    And the output mentions "repo/redis"
    And the output mentions "1.0.0"
    And the output mentions "Dry run"

  @offline
  Scenario: Dependents are listed as a warning
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "web/ghost" deployed
    And "web/app" declares a needs on "data/redis"
    When I dry-run destroy-one for "dev" targeting "redis"
    Then the command succeeds
    And the output mentions "web/app"

  # ── User Story 4 (P2) — non-interactive --yes ──────────────────────────────────

  @offline
  Scenario: --yes deletes a non-prod release without prompting
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "web/ghost" deployed
    When I run destroy-one for "dev" targeting "redis" with --yes
    Then the command succeeds
    And helmfile destroyed the release with selector "name=redis"
    And no confirmation was requested

  @offline
  Scenario: --yes without a release is refused
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "web/ghost" deployed
    When I run destroy-one for "dev" with --yes and no release
    Then the command fails
    And nothing was destroyed

  @offline
  Scenario: --yes cannot delete an unmanaged release
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "data/rogue" deployed
    When I run destroy-one for "dev" targeting "rogue" with --yes
    Then the command fails
    And nothing was destroyed
    And the output mentions "not a deletable release"

  @offline
  Scenario: --yes still requires confirmation on prod
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "web/ghost" deployed
    When I run destroy-one for "prod" targeting "redis" with --yes
    Then the command succeeds
    And a confirmation was requested

  # ── User Story 5 (P3) — shared selection library reused by install-one (#29) ────

  @offline
  Scenario: The guard logic lives only in the shared library
    Given the repository root
    Then the file "scripts/lib/helmfile.sh" contains "helmfile_selectable_releases"
    And the file "scripts/lib/helmfile.sh" contains "helmfile_dependents"
    And the file "scripts/helm/destroy-one.sh" contains "lib/helmfile.sh"
    And the file "scripts/helm/destroy-one.sh" contains "helmfile_selectable_releases"
    And the file "scripts/helm/destroy-one.sh" does not contain "--argjson"

  @offline
  Scenario: The shared library documents its public API for reuse by #29
    Given the repository root
    Then the file "scripts/lib/helmfile.sh" contains "Public API"
    And the file "scripts/lib/helmfile.sh" contains "install-one"

  @online
  Scenario: Deleting one release leaves the others running
    Given a reachable "dev" cluster with more than one managed release deployed
    When I delete a single throwaway release with destroy:one
    Then that release is gone
    And the other managed releases are still deployed
