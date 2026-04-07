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
| helm-lint | Lints Helm charts in `charts/` |
| helmfile-lint | Lints helmfile configurations in `helmfile/` |

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

## Helm Lint

[helm lint](https://helm.sh/docs/chart_template_guide/getting_started/) validates Helm chart structure, syntax, and best practices.

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
# or
brew install helm
```

### Usage

Lint all charts:

```bash
for chart in charts/*/; do
  helm lint "$chart"
done
```

### Configuration

The helm-lint hook is configured to run on chart directories in `charts/`. See `.pre-commit-config.yaml` for details.

## Helmfile Lint

[helmfile lint](https://helmfile.readthedocs.io/en/latest/#lint) validates helmfile configuration and charts.

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/helmfile/helmfile/main/scripts/get_helmfile.sh | sh
# or
brew install helmfile
```

### Usage

```bash
helmfile lint
```

### Bypassing Encrypted Secrets

By default, `helmfile lint` loads secrets from encrypted `.enc.yaml` files, which requires GPG keys. To run lint without access to real secrets (e.g., in pre-commit hooks), use the `--state-values-file` flag:

```bash
helmfile -f helmfile.yaml.gotmpl -e dev --state-values-file helmfile/environments/lint-values.yaml lint
```

This uses `helmfile/environments/lint-values.yaml` - a stub values file with empty placeholder values for all secrets. It allows lint to pass without GPG keys or decrypted secrets.

#### When to Update lint-values.yaml

If you add new secret templates or create new releases with secrets, update the lint-values file to include the new keys:

1. Check `helmfile/secret-templates/*.template.yaml` for new secret keys
2. Add corresponding empty values to `helmfile/environments/lint-values.yaml`
3. The lint will fail if required secret values are missing

### Configuration

The helmfile-lint hook is configured to run on YAML files in `helmfile/`. See `.pre-commit-config.yaml` for details.