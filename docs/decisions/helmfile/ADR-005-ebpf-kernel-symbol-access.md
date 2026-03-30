# ADR-005: Enable eBPF Profiling for Pyroscope via Alloy

- **Date**: 2026-03-30
- **Status**: Accepted
- **Deciders**: Homelab maintainers
- **Category**: monitoring

## Context

Alloy was deployed as the unified telemetry collector (see [ADR-002](ADR-002-alloy-replacing-promtail.md)) with eBPF-based CPU profiling via Pyroscope. The `pyroscope.ebpf "cpu"` component loads eBPF programs into the kernel to collect CPU profiles from all pods on the node.

After deployment, the eBPF tracer failed with a series of errors:

```
failed to read kernel symbols: unable to read kallsyms addresses - check capabilities
failed to mount tracefs at /sys/kernel/tracing: permission denied
failed to set temporary rlimit: operation not permitted
```

Three issues prevent eBPF profiling from working:

1. **Insufficient Linux capabilities**: Kernels 5.8+ require `CAP_BPF` and `CAP_PERFMON` for eBPF program loading. `CAP_SYS_ADMIN` alone is not sufficient. `CAP_SYSLOG` is needed to read `/proc/kallsyms`.

2. **Kernel symbol hiding**: The `kernel.kptr_restrict` sysctl controls whether kernel pointer addresses are exposed in `/proc/kallsyms`. When set to `1` or `2` (common on many distributions), all addresses appear as zeroes, making symbol resolution impossible.

3. **Missing filesystem mounts**: The eBPF tracer needs access to `tracefs` (`/sys/kernel/tracing`) for attaching probes and the `bpffs` (`/sys/fs/bpf`) for loading programs and maps. Without volume mounts, the container cannot access these host filesystems.

The Alloy configuration had `hostPID: true` and `SYS_ADMIN`+`SYS_PTRACE` capabilities, but was missing the newer eBPF-specific capabilities and required host filesystem mounts.

## Decision

Apply three changes to enable eBPF profiling:

1. Add Linux capabilities `BPF`, `PERFMON`, and `SYSLOG` to the Alloy security context.
2. Mount host `tracefs` and `bpffs` into the Alloy container via `hostPath` volumes.
3. Set `kernel.kptr_restrict=0` on all K3s nodes via the existing Ansible sysctl-tuning playbook.

## Alternatives Considered

### Option A: Enable hostNetwork on the Alloy DaemonSet (Not selected)
- **Description**: Set `hostNetwork: true` to give the pod direct access to the host's kernel and network namespace.
- **Pros**:
  - Theoretical alignment with eBPF host-level operations.
- **Cons**:
  - Breaks cluster DNS resolution (`*.svc.cluster.local`) because the pod no longer uses kube-dns/coredns.
  - Causes all Alloy pipelines to fail: logs (`loki-gateway`), profiles (`pyroscope`), and traces (`tempo`) become unreachable.
  - Unnecessary — eBPF requires kernel capabilities, `/proc` access, and tracefs/bpffs mounts, not host networking.

### Option B: Set kernel.kptr_restrict via pod securityContext sysctls (Not selected)
- **Description**: Use `securityContext.sysctls` in the Alloy pod spec to set `kernel.kptr_restrict=0`.
- **Pros**:
  - Appears scoped to the Alloy pod only.
- **Cons**:
  - Requires kubelet configuration with `--allowed-unsafe-sysctls=kernel.kptr_restrict` on all nodes.
  - `kernel.kptr_restrict` is a global namespace sysctl — it cannot be isolated to a pod; setting it changes it host-wide regardless.
  - More complex to reason about than a direct host-level setting.

### Option C: Run Alloy as privileged (Not selected)
- **Description**: Set `privileged: true` on the Alloy container.
- **Pros**:
  - Resolves all capability and mount issues trivially.
- **Cons**:
  - Grants far more access than needed (full device access, ability to modify the host).
  - Violates the principle of least privilege.

### Option D: Capabilities + host mounts + host-level sysctl (Selected)
- **Description**: Add the required capabilities (`BPF`, `PERFMON`, `SYSLOG`), mount host tracefs and bpffs, and set `kernel.kptr_restrict=0` on all nodes via Ansible.
- **Pros**:
  - Follows the principle of least privilege.
  - Host-level sysctl is the correct placement for a host-level kernel parameter.
  - `hostPID` provides process visibility; volume mounts provide filesystem access — both needed, neither alone sufficient.
  - Consistent with existing sysctl-tuning pattern established in [ADR-003](../ansible/ADR-003-sysctl-tuning.md).
- **Cons**:
  - `kernel.kptr_restrict=0` exposes kernel symbol addresses globally. Minor information disclosure (kernel version and build details), acceptable for a homelab.

## Consequences

### Positive
- eBPF profiling via Pyroscope works correctly across all nodes.
- Alloy retains granular capability control rather than running as privileged.
- `kernel.kptr_restrict=0` is managed declaratively via Ansible alongside other sysctl tuning.
- Existing log, profile, and trace pipelines remain unaffected.

### Negative
- `kernel.kptr_restrict=0` makes kernel symbol addresses globally readable. Kernel build information becomes visible via `/proc/kallsyms`.
- Host path volume mounts tie the DaemonSet to host filesystem layout (though `/sys/kernel/tracing` and `/sys/fs/bpf` are standard across Linux).

### Risks
- **Risk**: `kernel.kptr_restrict=0` exposes kernel symbol information, which could aid exploitation in a multi-tenant environment.
  - **Mitigation**: This is a single-user homelab. If the cluster becomes multi-tenant, revisit via a deprecation ADR.

## Configuration

### Alloy Helm values (`helmfile/common/values/alloy.yaml.gotmpl`)

Added capabilities and host filesystem mounts:

```yaml
alloy:
  mounts:
    varlog: true
    dockercontainers: true
    extra:
      - name: tracefs
        mountPath: /sys/kernel/tracing
        readOnly: false
      - name: bpffs
        mountPath: /sys/fs/bpf
        readOnly: false
  securityContext:
    privileged: false
    capabilities:
      add:
        - SYS_ADMIN
        - SYS_PTRACE
        - BPF          # eBPF program loading (kernel 5.8+)
        - PERFMON      # eBPF performance monitoring (kernel 5.8+)
        - SYSLOG       # Read /proc/kallsyms

controller:
  type: daemonset
  hostPID: true
  volumes:
    extra:
      - name: tracefs
        hostPath:
          path: /sys/kernel/tracing
          type: Directory
      - name: bpffs
        hostPath:
          path: /sys/fs/bpf
          type: Directory
```

### Ansible sysctl (`metal/k3s/playbooks/sysctl-tuning.yml`)

Added kernel parameter:

```yaml
- name: Set kernel.kptr_restrict for eBPF symbol resolution
  ansible.posix.sysctl:
    name: kernel.kptr_restrict
    value: "0"
    sysctl_set: true
    state: present
    reload: true
```

## References

- [ADR-002: Replace Promtail with Alloy for Log Collection](ADR-002-alloy-replacing-promtail.md)
- [ADR-003: Add sysctl tuning for K3s inotify limits](../ansible/ADR-003-sysctl-tuning.md)
- [Grafana Alloy pyroscope.ebpf component](https://grafana.com/docs/alloy/latest/reference/components/pyroscope/pyroscope.ebpf/)
- [Linux capabilities - BPF](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [kernel.kptr_restrict documentation](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/kernel.html#kptr-restrict)
- [eBPF filesystem (bpffs)](https://docs.kernel.org/bpf/bpf_design_QA.html#q-what-is-bpf-filesystem)
