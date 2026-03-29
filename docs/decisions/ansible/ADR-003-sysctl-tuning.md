# ADR-003: Add Sysctl Tuning for K3s Inotify Limits

- **Date**: 2026-03-29
- **Status**: Accepted
- **Deciders**: Homelab maintainers
- **Category**: infrastructure

## Context

K3s workloads running on the cluster frequently exhaust the default Linux `inotify` limits. The `inotify` subsystem monitors filesystem events (file watches), and Kubernetes components — including kubelet, container runtimes, and applications like Loki and Alloy — create many file watchers per pod.

Default kernel values are too low for container-heavy workloads:
- `fs.inotify.max_user_watches` defaults to `8192`
- `fs.inotify.max_user_instances` defaults to `128`

Symptoms include pods failing to start, `no space left on device` errors in logs, and file watching failures in applications.

## Decision

Apply sysctl tuning via an Ansible playbook that runs during cluster provisioning to increase inotify limits on all K3s nodes.

## Alternatives Considered

### Option A: Do nothing
- **Description**: Rely on default kernel values.
- **Pros**:
  - No additional configuration needed.
- **Cons**:
  - Pods crash or fail to start under load.
  - File watching errors in logging and monitoring agents.
  - Unpredictable behavior as workload count increases.

### Option B: Apply tuning via Ansible playbook (Selected)
- **Description**: Create an Ansible playbook that sets sysctl values on all `k3s_cluster` hosts.
- **Pros**:
  - Declarative, repeatable configuration managed as code.
  - Applied consistently across all nodes during provisioning.
  - Idempotent — safe to re-run.
- **Cons**:
  - Adds a step to the provisioning pipeline.

### Option C: Apply via DaemonSet or init container
- **Description**: Use a Kubernetes DaemonSet to apply sysctl at runtime.
- **Pros**:
  - Managed within Kubernetes.
- **Cons**:
  - Requires privileged containers.
  - Less transparent than host-level configuration.
  - Kubernetes should not manage host kernel parameters.

## Consequences

### Positive
- Pods and file watchers operate reliably under increased load.
- Consistent tuning across all K3s cluster nodes.
- Ansible playbook is idempotent and version-controlled.

### Negative
- Adds an additional step to the `metal/k3s/run.sh` provisioning script.
- Requires the `ansible.posix` collection for the `sysctl` module.

### Risks
- **Risk**: Excessively high values may consume kernel memory.
  - **Mitigation**: Values chosen (`524288` watches, `512` instances) are conservative and aligned with Kubernetes best practices.

## Configuration

Values applied:
- `fs.inotify.max_user_watches`: `524288`
- `fs.inotify.max_user_instances`: `512`

Playbook location: `metal/k3s/playbooks/sysctl-tuning.yml`

## References

- [Kubernetes inotify watches limit](https://kind.sigs.k8s.io/docs/user/known-issues#pod-errors-due-to-too-many-open-files)
- [Ansible posix.sysctl module](https://docs.ansible.com/ansible/latest/collections/ansible/posix/sysctl_module.html)
