# 🏠 Homelab

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

### Setup

#### 1. Clone the Repository

```bash
git clone https://github.com/albertoig/homelab.git
cd homelab
