# 🏠 Homelab

[![CI Pipeline](https://github.com/albertoig/homelab/actions/workflows/ci.yml/badge.svg)](https://github.com/albertoig/homelab/actions/workflows/ci.yml)
[![CodeQL](https://github.com/albertoig/homelab/actions/workflows/codeql.yml/badge.svg)](https://github.com/albertoig/homelab/actions/workflows/codeql.yml)
[![codecov](https://codecov.io/gh/albertoig/homelab/branch/main/graph/badge.svg)](https://codecov.io/gh/albertoig/homelab)
[![Dependabot](https://img.shields.io/badge/Dependabot-enabled-brightgreen?logo=dependabot)](https://dependabot.com/)
[![Python Version](https://img.shields.io/badge/Python-3.14+-blue?logo=python)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue?logo=gnu)](LICENSE)
[![Downloads](https://img.shields.io/badge/Downloads-N/A-lightgrey?logo=download)](#)
[![Last Release](https://img.shields.io/badge/Last_Release-N%2FA-red?logo=release)](https://github.com/albertoig/homelab/releases)
[![Security Policy](https://img.shields.io/badge/Security-Policy-blue?logo=lock)](./SECURITY.md)

A personal homelab setup using Kubernetes (K3s), Terraform, and GitOps practices.

---

## 📋 Overview

This repository contains the infrastructure as code (IaC) and configurations
for managing a personal homelab environment. It leverages modern DevOps tools
and best practices to automate and manage the entire lifecycle of the infrastructure.

---

## 🏗️ Architecture



---

## 🛠️ Tech Stack

| Tool | Purpose |
|------|---------|
| [K3s](https://k3s.io/) | Lightweight Kubernetes distribution |
| [Terraform](https://www.terraform.io/) | Infrastructure as Code |
| [Helmfile](https://helmfile.readthedocs.io/) | Helm releases management |
| [ArgoCD](https://argoproj.github.io/cd/) | GitOps continuous delivery |
| [SOPS](https://github.com/mozilla/sops) | Secrets encryption |
| [Age](https://age-encryption.org/) | Encryption tool for SOPS |

---

## 📌 Roadmap
See our [ROADMAP.md](./ROADMAP.md) for upcoming features and progress.

---

## 🚀 Getting Started

### Prerequisites

Make sure you have the following tools installed:

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [terraform](https://developer.hashicorp.com/terraform/install)
- [helm](https://helm.sh/docs/intro/install/)
- [helmfile](https://helmfile.readthedocs.io/en/latest/#installation)
- [sops](https://github.com/mozilla/sops#installation)
- [age](https://github.com/FiloSottile/age#installation)

### Required Helm Plugins

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

# Install helm-secrets plugin
helm plugin install https://github.com/jkroepke/helm-secrets/releases/download/v4.7.4/secrets-4.7.4.tgz --keyring ~/.config/helm/keys/jkroepke.gpg

# Install helm-secrets getter plugin
helm plugin install https://github.com/jkroepke/helm-secrets/releases/download/v4.7.4/secrets-getter-4.7.4.tgz --keyring ~/.config/helm/keys/jkroepke.gpg

# Install helm-secrets post-renderer plugin
helm plugin install https://github.com/jkroepke/helm-secrets/releases/download/v4.7.4/secrets-post-renderer-4.7.4.tgz --keyring ~/.config/helm/keys/jkroepke.gpg

# Install helm-diff plugin
helm plugin install https://github.com/databus23/helm-diff --verify false

# Cleanup raw key file after use
rm ~/.config/helm/keys/jkroepke.gpg.raw

```