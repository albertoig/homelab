# Megahomelab

Pulumi infrastructure as code for homelab k3s cluster using Python 3.14.

## Installation

```bash
cd pulumi
poetry install
```

## Development Installation

To install as a development tool (available as `megahomelab` command):

```bash
poetry install
poetry add -g /path/to/pulumi
```

Or install system-wide:

```bash
poetry build
pip install dist/megahomelab-*.whl
```

## Usage

### Initialize an environment

```bash
megahomelab init dev
```

This will:
1. Ask for kubeconfig path (default: `~/.kube/config`)
2. List available Kubernetes contexts
3. Allow you to select a context
4. Store the configuration in `~/.homelab/config` (single file with multiple environments)

### Deploy infrastructure

```bash
megahomelab up dev
```

### Other commands

- `megahomelab configure <env>` - Reconfigure kubeconfig
- `megahomelab status <env>` - Show configuration status
- `megahomelab preview <env>` - Preview changes
- `megahomelab destroy <env>` - Destroy resources

## Configuration

- **Config file**: `~/.homelab/config` (single YAML file with multiple environments)
- **Pulumi state**: `~/.homelab/statefiles/{environment}.state`

Example config file structure:
```yaml
dev:
  kubeconfig_path: /home/user/.kube/config
  kubeconfig_context: k3s-dev
prod:
  kubeconfig_path: /home/user/.kube/config
  kubeconfig_context: k3s-prod
```
