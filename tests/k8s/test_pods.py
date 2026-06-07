import pytest
from kubernetes import client


NAMESPACES = [
    "auth-system",
    "gitops-system",
    "monitoring-system",
    "longhorn-system",
    "velero-system",
    "cert-manager-system",
    "ingress-system",
    "lb-system",
]


def _pods_in_namespace(k8s: client.CoreV1Api, namespace: str) -> list:
    try:
        return k8s.list_namespaced_pod(namespace).items
    except client.exceptions.ApiException as e:
        if e.status == 404:
            pytest.skip(f"Namespace {namespace} not found")
        raise


@pytest.mark.parametrize("namespace", NAMESPACES)
class TestPodHealth:
    def test_no_pods_in_crashloop(self, k8s, namespace):
        pods = _pods_in_namespace(k8s, namespace)
        assert pods, f"No pods found in {namespace}"

        crashlooping = [
            p.metadata.name
            for p in pods
            if p.status.container_statuses
            for cs in p.status.container_statuses
            if cs.state.waiting and cs.state.waiting.reason == "CrashLoopBackOff"
        ]
        assert not crashlooping, f"CrashLoopBackOff in {namespace}: {crashlooping}"

    def test_all_pods_running_or_completed(self, k8s, namespace):
        pods = _pods_in_namespace(k8s, namespace)
        assert pods, f"No pods found in {namespace}"

        bad = [
            f"{p.metadata.name} ({p.status.phase})"
            for p in pods
            if p.status.phase not in ("Running", "Succeeded")
        ]
        assert not bad, f"Unhealthy pods in {namespace}: {bad}"


class TestPersistentVolumes:
    def test_all_pvcs_bound(self, k8s):
        pvcs = k8s.list_persistent_volume_claim_for_all_namespaces().items
        unbound = [
            f"{p.metadata.namespace}/{p.metadata.name} ({p.status.phase})"
            for p in pvcs
            if p.status.phase != "Bound"
        ]
        assert not unbound, f"Unbound PVCs: {unbound}"
