Feature: Spec Kit adoption
  As a maintainer of the homelab platform
  I want Spec-Driven Development scaffolding and a BDD verification loop in place
  So that every change starts from a spec and can be verified before it ships

  @offline
  Scenario: The Spec Kit scaffolding is present
    Given the repository root
    Then the directory ".specify" exists
    And the directory "specs" exists
    And the file ".specify/templates/spec-template.md" exists

  @offline
  Scenario: The project constitution is filled in
    Given the repository root
    Then the file ".specify/memory/constitution.md" exists
    And the file ".specify/memory/constitution.md" does not contain "[PRINCIPLE_1_NAME]"
    And the file ".specify/memory/constitution.md" contains "Helmfile Is the Source of Truth"

  @offline
  Scenario: The Spec Kit agent integration is installed
    # This repo commits the Claude Code integration; Spec Kit is agent-agnostic and other
    # agents can be added with `specify init`. We assert the integration we actually ship.
    Given the repository root
    Then the directory ".claude/skills/speckit-specify" exists
    And the directory ".claude/skills/speckit-plan" exists
    And the directory ".claude/skills/speckit-tasks" exists
    And the directory ".claude/skills/speckit-implement" exists

  @offline
  Scenario: The verification loop is wired into mise with an offline/online split
    Given the repository root
    Then the file ".mise.toml" contains "verify:offline"
    And the file ".mise.toml" contains "offline or online"
    And the file ".mise.toml" contains "[tasks.verify]"

  @offline
  Scenario: Locally verify runs both tags; CI runs only offline
    Given the repository root
    Then "mise run verify" runs both offline and online scenarios
    And "mise run verify:offline" runs only offline scenarios
    And no CI workflow runs online scenarios

  @offline
  Scenario: The GitHub pipeline runs the offline verification task
    Given the repository root
    Then a CI workflow runs "mise run verify:offline"

  @offline
  Scenario: The pre-commit hook enforces the offline verification
    Given the repository root
    Then the file ".pre-commit-config.yaml" contains "verify:offline"
    And the file ".pre-commit-config.yaml" contains "offline-bdd"

  @offline
  Scenario Outline: Offline spec verification is enforced in CI on every branch
    Given the repository root
    Then a CI workflow runs the offline BDD verification on a push to "<branch>"

    Examples:
      | branch |
      | main   |
      | beta   |
      | feat/some-feature |
