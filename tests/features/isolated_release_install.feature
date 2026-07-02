Feature: Isolated install/update of a single Helmfile release
  As a homelab operator
  I want to install or update one Helmfile-managed release by name
  So that I can roll out a single component without syncing the whole environment

  # ── User Story 1 (P1) — safe by-name install/update + YAML/cluster guard ───────

  @offline
  Scenario: The install:one task is wired into mise like destroy:one
    Given the repository root
    Then the mise task "install:one" runs "./scripts/helm/install-one.sh"
    And the file ".mise.toml" contains "install:one"

  @offline
  Scenario: The guard logic lives in the shared library and the script sources it
    Given the repository root
    Then the file "scripts/lib/helmfile.sh" exists
    And the file "scripts/helm/install-one.sh" contains "lib/helmfile.sh"
    And the file "scripts/helm/install-one.sh" contains "helmfile_installable_rows"

  @offline
  Scenario: Installing a defined release that is not deployed syncs it as an install
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "web/ghost" deployed
    When I run install-one for "dev" targeting "redis"
    Then the command succeeds
    And helmfile synced the release with selector "name=redis"
    And the sync used "--skip-deps"
    And the output mentions "install"
    And only one release was synced

  @offline
  Scenario: Updating a defined release that is already deployed syncs it as an update
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "web/ghost" deployed
    When I run install-one for "dev" targeting "redis"
    Then the command succeeds
    And helmfile synced the release with selector "name=redis"
    And the output mentions "update"

  @offline
  Scenario: A release running in the cluster but not defined in YAML is refused
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "data/rogue" deployed
    When I run install-one for "dev" targeting "rogue"
    Then the command fails
    And nothing was synced
    And the output mentions "not defined in the Helmfile"

  @offline
  Scenario: An unknown release name is refused
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" deployed
    When I run install-one for "dev" targeting "nope"
    Then the command fails
    And nothing was synced
    And the output mentions "not a defined release"

  # ── User Story 2 (P2) — interactive picker ─────────────────────────────────────

  @offline
  Scenario: With no release argument the picker lists every defined release
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "web/ghost" and "data/rogue" deployed
    When I run install-one for "dev" with no release
    Then the command succeeds
    And the picker offered "data/redis"
    And the picker offered "web/ghost"
    And the picker did not offer "data/rogue"

  @offline
  Scenario: The picker annotates each release with its install or update action
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "web/ghost" deployed
    When I run install-one for "dev" with no release
    Then the command succeeds
    And the picker offered a row for "data/redis" tagged "install"
    And the picker offered a row for "web/ghost" tagged "update"

  @offline
  Scenario: Cancelling the picker syncs nothing
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" deployed
    When I cancel the picker for "dev"
    Then the command succeeds
    And nothing was synced

  # ── User Story 2b (P2) — progress feedback while waiting on the cluster ────────

  @offline
  Scenario: Loading the selectable releases shows a progress spinner
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" deployed
    When I run install-one for "dev" targeting "redis"
    Then the command succeeds
    And a loading spinner titled "Loading releases" was shown

  @offline
  Scenario: Syncing a release shows a progress spinner
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" deployed
    When I run install-one for "dev" targeting "redis"
    Then the command succeeds
    And a loading spinner titled "Syncing redis" was shown

  # ── User Story 3 (P2) — dry-run preview + prerequisite warning ─────────────────

  @offline
  Scenario: Dry run previews the release and makes no changes
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" deployed
    When I dry-run install-one for "dev" targeting "redis"
    Then the command succeeds
    And nothing was synced
    And the output mentions "redis"
    And the output mentions "repo/redis"
    And the output mentions "1.0.0"
    And the output mentions "update"
    And the output mentions "Dry run"

  @offline
  Scenario: Prerequisites are listed as a warning
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" deployed
    And "data/redis" declares a needs on "data/postgres"
    When I dry-run install-one for "dev" targeting "redis"
    Then the command succeeds
    And the output mentions "data/postgres"

  # ── User Story 4 (P2) — non-interactive --yes ──────────────────────────────────

  @offline
  Scenario: --yes syncs a non-prod release without prompting
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" deployed
    When I run install-one for "dev" targeting "redis" with --yes
    Then the command succeeds
    And helmfile synced the release with selector "name=redis"
    And no confirmation was requested

  @offline
  Scenario: --yes without a release is refused
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" deployed
    When I run install-one for "dev" with --yes and no release
    Then the command fails
    And nothing was synced

  @offline
  Scenario: --yes cannot sync an unmanaged release
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" and "data/rogue" deployed
    When I run install-one for "dev" targeting "rogue" with --yes
    Then the command fails
    And nothing was synced
    And the output mentions "not defined in the Helmfile"

  @offline
  Scenario: --yes still requires confirmation on prod
    Given a Helmfile defining "data/redis" and "web/ghost"
    And the cluster has "data/redis" deployed
    When I run install-one for "prod" targeting "redis" with --yes
    Then the command succeeds
    And a confirmation was requested

  # ── User Story 5 (P3) — shared selection library reused from destroy-one ───────

  @offline
  Scenario: The install set is derived by the shared library, not inline
    Given the repository root
    Then the file "scripts/lib/helmfile.sh" contains "helmfile_installable_rows"
    And the file "scripts/lib/helmfile.sh" contains "helmfile_requirements"
    And the file "scripts/helm/install-one.sh" contains "lib/helmfile.sh"
    And the file "scripts/helm/install-one.sh" does not contain "--argjson"

  @online
  Scenario: Syncing one release leaves the others untouched
    Given a reachable "dev" cluster with more than one managed release deployed
    When I sync a single throwaway release with install:one
    Then that release is present at the defined version
    And the other managed releases are unchanged
