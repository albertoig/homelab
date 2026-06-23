"""Smoke test: the right users are members of the Authentik admin groups.

The admin groups are provisioned declaratively by the authentik-blueprints chart
(Grafana / ArgoCD / OpenBao Admins). Membership drives access: e.g. the OpenBao
OIDC login only grants the admin policy to members of "OpenBao Admins". This test
verifies both the homelab SSO admin and Authentik's built-in superuser (akadmin)
are in every admin group.

Group membership is read by exec'ing `ak shell` in the authentik-server pod, so
no Authentik API token is needed. Uses the current kube context.
"""
import base64
import json

import pytest
from kubernetes import client
from kubernetes.stream import stream

AUTH_NS = "auth-system"
ADMIN_GROUPS = ["Grafana Admins", "ArgoCD Admins", "OpenBao Admins"]


def _server_pod(k8s: client.CoreV1Api) -> str:
    try:
        pods = k8s.list_namespaced_pod(AUTH_NS).items
    except client.exceptions.ApiException as e:
        if e.status == 404:
            pytest.skip(f"Namespace {AUTH_NS} not found")
        raise
    running = [
        p.metadata.name
        for p in pods
        if p.metadata.name.startswith("authentik-server")
        and p.status.phase == "Running"
    ]
    if not running:
        pytest.skip("authentik-server pod not running")
    return running[0]


def _ak_group_members(k8s: client.CoreV1Api) -> dict:
    """Return {group_name: [usernames] or None if the group is missing}."""
    expr = (
        "import json;"
        "from authentik.core.models import Group;"
        f"groups={json.dumps(ADMIN_GROUPS)};"
        "out={g:([u.username for u in Group.objects.filter(name=g).first().users.all()]"
        " if Group.objects.filter(name=g).first() else None) for g in groups};"
        "print('SSO_GROUPS_JSON='+json.dumps(out))"
    )
    out = stream(
        k8s.connect_get_namespaced_pod_exec,
        _server_pod(k8s),
        AUTH_NS,
        command=["ak", "shell", "-c", expr],
        stdout=True,
        stderr=True,
        stdin=False,
        tty=False,
        _preload_content=True,
    )
    for line in out.splitlines():
        if line.startswith("SSO_GROUPS_JSON="):
            return json.loads(line[len("SSO_GROUPS_JSON=") :])
    pytest.fail(f"could not parse group membership from ak shell output:\n{out}")


def _homelab_admin_username(k8s: client.CoreV1Api) -> str:
    try:
        secret = k8s.read_namespaced_secret("authentik-initial-config-secrets", AUTH_NS)
    except client.exceptions.ApiException as e:
        if e.status == 404:
            pytest.skip("authentik-initial-config-secrets not found")
        raise
    raw = (secret.data or {}).get("HOMELAB_ADMIN_USERNAME")
    if not raw:
        pytest.skip("HOMELAB_ADMIN_USERNAME not set")
    return base64.b64decode(raw).decode().strip()


@pytest.fixture(scope="module")
def group_members(k8s) -> dict:
    return _ak_group_members(k8s)


@pytest.fixture(scope="module")
def expected_admins(k8s) -> set:
    # Both the configured homelab SSO admin and Authentik's built-in superuser.
    return {"akadmin", _homelab_admin_username(k8s)}


@pytest.mark.parametrize("group", ADMIN_GROUPS)
class TestAdminGroupMembership:
    def test_group_exists(self, group_members, group):
        assert group_members.get(group) is not None, (
            f"Authentik group '{group}' does not exist"
        )

    def test_expected_admins_are_members(self, group_members, expected_admins, group):
        members = set(group_members.get(group) or [])
        missing = expected_admins - members
        assert not missing, (
            f"{group} is missing {sorted(missing)} (members: {sorted(members)})"
        )
