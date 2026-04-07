# Testing

This document describes the testing practices and tools used in this project.

## Pre-commit Hooks

This project uses [pre-commit](https://pre-commit.com/) to automate code quality checks before commits. The configuration is in `.pre-commit-config.yaml`.

### Setup

Install pre-commit hooks:

```bash
pip install pre-commit
pre-commit install
```

### Available Hooks

| Hook | Purpose |
|------|---------|
| ansible-lint | Lints Ansible playbooks in `metal/k3s/playbooks/` |

### Running Hooks

Run all hooks manually:

```bash
pre-commit run --all-files
```

Skip hooks (use with caution):

```bash
git commit --no-verify
```

## Ansible Lint

[ansible-lint](https://ansible-lint.readthedocs.io/) validates Ansible playbooks for best practices, syntax errors, and common mistakes.

### Installation

```bash
pip install ansible-lint
# or
pipx install ansible-lint
```

### Usage

Lint specific files or directories:

```bash
ansible-lint metal/k3s/playbooks/
```

Lint all playbook files:

```bash
ansible-lint
```

### Configuration

The ansible-lint hook is configured to run on YAML files in `metal/k3s/playbooks/`. See `.pre-commit-config.yaml` for details.