# Kseed

Pulumi infrastructure as code for homelab k3s cluster using Python 3.14.

## Installation

```bash
cd pulumi
poetry install
```

## Development Installation

To install as a development tool (available as `kseed` command):

```bash
poetry install
poetry add -g /path/to/pulumi
```

Or install system-wide:

```bash
poetry build
pip install dist/kseed-*.whl
```

## Usage

### Initialize an environment

```bash
kseed init dev
```

This will:
1. Ask for kubeconfig path (default: `~/.kube/config`)
2. List available Kubernetes contexts
3. Allow you to select a context
4. Store the configuration in `~/.kseed/config` (single file with multiple environments)

### Deploy infrastructure

```bash
kseed up dev
```

### Other commands

- `kseed configure <env>` - Reconfigure kubeconfig
- `kseed status <env>` - Show configuration status
- `kseed preview <env>` - Preview changes
- `kseed destroy <env>` - Destroy resources

## Configuration

- **Config file**: `~/.kseed/config` (single YAML file with multiple environments)
- **Pulumi state**: `~/.kseed/statefiles/{environment}.state`

Example config file structure:
```yaml
dev:
  kubeconfig_path: /home/user/.kube/config
  kubeconfig_context: k3s-dev
prod:
  kubeconfig_path: /home/user/.kube/config
  kubeconfig_context: k3s-prod
```
