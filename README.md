# 🏠 Homelab

A personal homelab setup using Kubernetes (K3s), Helmfile, and GitOps practices for automated infrastructure management.

---

## 📋 Overview

This repository contains the infrastructure as code (IaC) and configurations for managing a personal homelab environment. It leverages modern DevOps tools and best practices to automate and manage the entire lifecycle of the infrastructure.

The homelab is designed to be:
- **Automated**: Infrastructure is managed as code using Terraform and Helmfile
- **Secure**: Secrets are encrypted using SOPS and Age
- **Observable**: Comprehensive monitoring with Prometheus, Grafana, Loki, and Tempo
- **GitOps-driven**: ArgoCD for continuous delivery and GitOps workflows

---

## 🏗️ Architecture

The homelab follows a layered architecture:

1. **Infrastructure Layer**: K3s cluster provisioned with Ansible
2. **Platform Layer**: Core services (MetalLB, Traefik, cert-manager) for networking and certificates
3. **Application Layer**: Applications deployed via Helmfile (ArgoCD, Authentik, Grafana, etc.)
4. **Observability Layer**: Monitoring (Prometheus), Logging (Loki), and Tracing (Tempo)

### Services Deployed

| Service | Purpose | Namespace |
|---------|---------|-----------|
| K3s | Lightweight Kubernetes | - |
| MetalLB | Load balancer for bare metal | metallb-system |
| Traefik | Reverse proxy and ingress | traefik |
| cert-manager | SSL/TLS certificate management | cert-manager-system |
| external-dns | DNS management with Cloudflare | cert-manager-system |
| Longhorn | Distributed block storage | longhorn-system |
| Prometheus Stack | Monitoring and alerting | prometheus |
| Grafana | Metrics visualization | prometheus |
| Loki | Log aggregation | prometheus |
| Tempo | Distributed tracing | prometheus |
| Authentik | Identity provider | authentik |
| ArgoCD | GitOps continuous delivery | argocd |

---

## 🛠️ Tech Stack

| Tool | Purpose |
|------|---------|
| [K3s](https://k3s.io/) | Lightweight Kubernetes distribution |
| [Ansible](https://www.ansible.com/) | Cluster provisioning and configuration |
| [Helmfile](https://helmfile.readthedocs.io/) | Helm releases management |
| [Helm](https://helm.sh/) | Kubernetes package manager |
| [ArgoCD](https://argoproj.github.io/cd/) | GitOps continuous delivery |
| [SOPS](https://github.com/mozilla/sops) | Secrets encryption |
| [Age](https://age-encryption.org/) | Encryption tool for SOPS |
| [Prometheus](https://prometheus.io/) | Monitoring and alerting |
| [Grafana](https://grafana.com/) | Metrics visualization |
| [Loki](https://grafana.com/oss/loki/) | Log aggregation |
| [Tempo](https://grafana.com/oss/tempo/) | Distributed tracing |
| [Longhorn](https://longhorn.io/) | Cloud-native distributed block storage |
| [MetalLB](https://metallb.universe.tf/) | Load balancer for bare metal Kubernetes |
| [Traefik](https://traefik.io/) | Cloud-native reverse proxy |
| [cert-manager](https://cert-manager.io/) | X.509 certificate management |
| [external-dns](https://github.com/kubernetes-sigs/external-dns/) | Synchronize exposed services with DNS providers |
| [Authentik](https://goauthentik.io/) | Identity provider |
| [Cloudflare](https://www.cloudflare.com/) | DNS and CDN provider |

---

## 📁 Project Structure

```
homelab/
├── charts/                    # Custom Helm charts
│   ├── cert-manager-config/   # Certificate configuration
│   ├── external-ingress/      # Ingress definitions
│   └── metallb-config/        # MetalLB configuration
├── docs/                      # Documentation
├── helmfile/                  # Helmfile configuration
│   ├── common/                # Common values and templates
│   │   ├── values/            # Service values files
│   │   └── common.yaml.gotmpl # Main releases definition
│   ├── environments/          # Environment-specific configs
│   │   ├── dev/               # Development environment
│   │   └── prod/              # Production environment
│   └── locks/                 # Helmfile lock files
├── metal/                     # Bare metal provisioning
│   └── k3s/                   # K3s cluster setup with Ansible
├── scripts/                   # Utility scripts
├── helmfile.yaml.gotmpl       # Main Helmfile entry point
├── ROADMAP.md                 # Project roadmap
└── README.md                  # This file
```

---

## 🚀 Getting Started

### Prerequisites

Make sure you have the following tools installed:

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [terraform](https://developer.hashicorp.com/terraform/install)
- [helm](https://helm.sh/docs/intro/install/)
- [helmfile](https://helmfile.readthedocs.io/en/latest/#installation)
- [sops](https://github.com/mozilla/sops#installation)
- [ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html)

### Required Helm Plugins

**⚠️ Important**: The following Helm plugins are **required** for this homelab to function properly. Without these plugins, Helmfile will not be able to manage secrets or show diffs during deployments.

After installing Helm, make sure to install the following plugins:

```bash
# Create a secure directory for GPG keys
mkdir -p ~/.config/helm/keys
chmod 700 ~/.config/helm/keys

# Import GPG key for helm-secrets plugin
curl -fsSL https://github.com/jkroepke.gpg -o ~/.config/helm/keys/jkroepke.gpg.raw

# Convert key to legacy GPG format
gpg --dearmor < ~/.config/helm/keys/jkroepke.gpg.raw > ~/.config/helm/keys/jkroepke.gpg
chmod 600 ~/.config/helm/keys/jkroepke.gpg

# Verify the key is valid
gpg --no-default-keyring --keyring ~/.config/helm/keys/jkroepke.gpg --list-keys

# Install helm-secrets plugin (REQUIRED)
helm plugin install https://github.com/jkroepke/helm-secrets/releases/download/v4.7.4/secrets-4.7.4.tgz --keyring ~/.config/helm/keys/jkroepke.gpg

# Install helm-secrets getter plugin (REQUIRED)
helm plugin install https://github.com/jkroepke/helm-secrets/releases/download/v4.7.4/secrets-getter-4.7.4.tgz --keyring ~/.config/helm/keys/jkroepke.gpg

# Install helm-secrets post-renderer plugin (REQUIRED)
helm plugin install https://github.com/jkroepke/helm-secrets/releases/download/v4.7.4/secrets-post-renderer-4.7.4.tgz --keyring ~/.config/helm/keys/jkroepke.gpg

# Install helm-diff plugin (REQUIRED)
helm plugin install https://github.com/databus23/helm-diff --verify false

# Cleanup raw key file after use
rm ~/.config/helm/keys/jkroepke.gpg.raw

```

### Verify Plugin Installation

After installing the plugins, verify they are correctly installed:

```bash
# List installed Helm plugins
helm plugin list

# You should see:
# - secrets
# - secrets-getter
# - secrets-post-renderer
# - diff
```

### Cluster Setup

1. **Provision K3s cluster**:
   ```bash
   cd metal/k3s
   ./run.sh
   ```

2. **Deploy infrastructure**:
   ```bash
   ./scripts/install-helmfiles.sh dev
   ```

   This runs the full deployment in order:
   1. Check CLI requirements and Kubernetes access
   2. Apply CRDs
   3. Apply certifications
   4. Apply common releases (monitoring, auth, etc.)
   5. Apply ingresses

3. **Verify deployment**:
   ```bash
   kubectl get pods -A
   ```

---

## 🔧 Configuration

### Environment-Specific Configuration

The homelab supports multiple environments (dev, prod). Environment-specific configurations are stored in:
- `helmfile/environments/<env>/values/` - Values files
- `helmfile/environments/<env>/secrets/` - Encrypted secrets

### Secrets Management

Secrets are encrypted using SOPS with Age encryption. Only `dev` and `prod` environments are supported.

```bash
# Decrypt secrets
./scripts/sops-decrypt-secrets.sh dev
./scripts/sops-decrypt-secrets.sh prod

# Encrypt secrets
./scripts/sops-encrypt-secrets.sh dev
./scripts/sops-encrypt-secrets.sh prod
```

---

## 📊 Monitoring

The homelab includes a comprehensive monitoring stack:

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation
- **Tempo**: Distributed tracing

### Accessing Grafana

Grafana is exposed via MetalLB LoadBalancer. Access it using the external IP assigned by MetalLB.

### Pre-configured Dashboards

- Kubernetes Cluster
- Node Exporter
- Kubernetes Pods
- MetalLB
- Longhorn
- CoreDNS
- External DNS
- Authentik
- ArgoCD Operations
- ArgoCD Application
- ArgoCD Notifications

---

## 📌 Roadmap

See our [ROADMAP.md](./ROADMAP.md) for upcoming features and progress.

## 📐 Architecture Decisions

See [docs/decisions/INDEX.md](./docs/decisions/INDEX.md) for architecture decision records (ADRs) documenting the reasoning behind significant infrastructure and configuration changes.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Commit Message Format

This project follows the [Conventional Commits](https://www.conventionalcommits.org/) specification (Angular convention) for commit messages. This enables automatic versioning and changelog generation via semantic-release.

**Format**: `type(scope): description`

**Types**:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, missing semi-colons, etc.)
- `refactor`: Code refactoring without feature changes or bug fixes
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks, dependency updates, etc.
- `ci`: CI/CD configuration changes
- `build`: Build system or external dependency changes
- `revert`: Reverting a previous commit

**Examples**:
- `feat(helmfile): add prometheus monitoring stack`
- `fix(cert-manager): resolve certificate renewal issue`
- `docs(readme): update installation instructions`
- `chore(deps): update helm chart versions`

### Contribution Steps

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes using the conventional commit format (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [K3s](https://k3s.io/) for the lightweight Kubernetes distribution
- [Helmfile](https://helmfile.readthedocs.io/) for Helm releases management
- [ArgoCD](https://argoproj.github.io/cd/) for GitOps continuous delivery
- [Prometheus](https://prometheus.io/) for monitoring
- [Grafana](https://grafana.com/) for visualization

---

## ⚠️ AI Training Notice

**This project does not authorize the use of its code, documentation, or any associated materials for training artificial intelligence (AI) or machine learning (ML) models.** Any use of this repository's content for AI/ML training purposes is strictly prohibited without explicit written permission from the project owner.
