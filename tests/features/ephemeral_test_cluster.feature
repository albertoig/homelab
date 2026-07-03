Feature: Ephemeral test cluster and hermetic test env for deep online BDD
  As a maintainer
  I want a disposable local cluster and a trivial test environment
  So that I can run real online tests of the isolated release tools without touching dev/prod

  # ── User Story 1 (P1) — disposable cluster wiring ──────────────────────────────

  @offline
  Scenario: The ephemeral cluster tool is pinned via mise
    Given the repository root
    Then the file ".mise.toml" contains "kind"

  @offline
  Scenario: The cluster lifecycle tasks are wired and target a test-only context
    Given the repository root
    Then the mise task "cluster:test:up" runs "kind"
    And the mise task "cluster:test:down" runs "kind"
    And the file ".mise.toml" contains "kind-homelab-test"

  # ── User Story 2 (P1) — hermetic test environment ──────────────────────────────

  @offline
  Scenario: A hermetic test environment is declared and pinned to the test cluster
    Given the repository root
    Then the file "helmfile.yaml.gotmpl" contains "kind-homelab-test"

  @offline
  Scenario: The test environment uses a trivial, dependency-free local chart
    Given the repository root
    Then the file "charts/test-app/Chart.yaml" exists
    And the file "helmfile/releases/900-test.helmfile.yaml.gotmpl" exists

  # ── Safety: @online must never act on a real homelab cluster ───────────────────
  # The disposable test context is deliberately named `kind-homelab-test`, NOT
  # `homelab-test`, so the guard can refuse every `homelab-*` context wholesale
  # (protecting dev/prod) while still allowing the throwaway test context (FR-012).

  @offline
  Scenario Outline: The @online guard refuses homelab contexts and allows only the test context
    Given the repository root
    Then the online cluster guard "<verdict>" the "<ctx>" context

    Examples:
      | ctx               | verdict |
      | homelab-dev       | refuses |
      | homelab-prod      | refuses |
      | kind-homelab-test | allows  |

  # ── User Story 1 — @online cluster reachable + isolated from homelab ────────────

  @online
  Scenario: The ephemeral cluster uses a dedicated context, isolated from homelab
    Given a reachable test cluster
    Then the "kind-homelab-test" context is reachable
    And no homelab context was modified

  # ── User Story 2 — @online hermetic sync ───────────────────────────────────────

  @online
  Scenario: The test environment syncs onto the ephemeral cluster
    Given a reachable test cluster
    When I sync the test environment
    Then at least two test releases are deployed
