"""Cluster health check functionality."""

from dataclasses import dataclass
from enum import Enum
from pathlib import Path

import yaml
from kubernetes import client
from kubernetes.client import ApiClient
from kubernetes.client.exceptions import ApiException


class HealthStatus(Enum):
    """Health status enum."""

    HEALTHY = "healthy"
    UNHEALTHY = "unhealthy"
    UNKNOWN = "unknown"


@dataclass
class ClusterHealth:
    """Cluster health check result."""

    environment: str
    cluster_reachable: bool
    has_permissions: bool
    can_install_helm: bool
    cluster_info: str | None = None
    error_message: str | None = None


def _load_kubeconfig(kubeconfig_path: Path, context_name: str) -> ApiClient:
    """Load kubeconfig and return API client."""
    with open(kubeconfig_path) as f:
        config = yaml.safe_load(f)

    # Find the context
    context = None
    for ctx in config.get("contexts", []):
        if ctx["name"] == context_name:
            context = ctx["context"]
            break

    if not context:
        raise ValueError(f"Context '{context_name}' not found in kubeconfig")

    # Get cluster info
    cluster_name = context.get("cluster")
    user_name = context.get("user")

    cluster_info = None
    for cluster in config.get("clusters", []):
        if cluster["name"] == cluster_name:
            cluster_info = cluster["cluster"]
            break

    user_info = None
    for user in config.get("users", []):
        if user["name"] == user_name:
            user_info = user.get("user", {})
            break

    # Build context-specific kubeconfig
    context_config = {
        "apiVersion": "v1",
        "kind": "Config",
        "contexts": [{"name": context_name, "context": context}],
        "current-context": context_name,
        "clusters": [{"name": cluster_name, "cluster": cluster_info}],
        "users": [{"name": user_name, "user": user_info}],
    }

    # Load using kubernetes config
    from kubernetes import config

    # Create a temporary kubeconfig file
    import tempfile

    with tempfile.NamedTemporaryFile(mode="w", suffix=".kubeconfig", delete=False) as tmp:
        yaml.safe_dump(context_config, tmp)
        tmp_path = tmp.name

    try:
        # Load from the temp file into the default config
        config.load_kube_config(config_file=tmp_path)
        # Get the configuration from the default
        return client.ApiClient()
    finally:
        Path(tmp_path).unlink(missing_ok=True)


def check_cluster_health(
    environment: str, kubeconfig_path: Path, context_name: str
) -> ClusterHealth:
    """Check cluster health for a given environment.

    Args:
        environment: The environment name
        kubeconfig_path: Path to the kubeconfig file
        context_name: The Kubernetes context to use

    Returns:
        ClusterHealth object with check results
    """
    result = ClusterHealth(
        environment=environment,
        cluster_reachable=False,
        has_permissions=False,
        can_install_helm=False,
    )

    try:
        # Load kubeconfig
        api_client = _load_kubeconfig(kubeconfig_path, context_name)

        # Create API clients
        core_v1 = client.CoreV1Api(api_client)
        apps_v1 = client.AppsV1Api(api_client)

        # Test 1: Check if cluster is reachable
        try:
            version_api = client.VersionApi(api_client)
            version = version_api.get_code()
            result.cluster_reachable = True
            result.cluster_info = f"k3s version: {version.git_version}"
        except ApiException as e:
            result.error_message = f"Cannot reach cluster: {e.reason}"
            return result

        # Test 2: Check if user has permissions (try to list namespaces)
        try:
            core_v1.list_namespace(limit=1)
            result.has_permissions = True
        except ApiException as e:
            result.error_message = f"Permission denied: {e.reason}"
            return result

        # Test 3: Check if user can install Helm (try to list CRDs which helm creates)
        try:
            # Check if we can at least see the API - this is a proxy for helm permissions
            # A full helm check would require actually trying to install a helm chart
            # which we don't want to do in a health check
            apps_v1.list_namespaced_deployment(namespace="kube-system", limit=1)
            result.can_install_helm = True
        except ApiException as e:
            if e.reason == "Forbidden":
                result.error_message = f"Cannot install Helm: {e.reason}"
            else:
                # If it's not a permission error, likely still ok for helm
                result.can_install_helm = True

    except Exception as e:
        result.error_message = str(e)

    return result


def get_all_configured_environments() -> list[str]:
    """Get all configured environments from the config file."""
    from kseed.config.manager import CONFIG_FILE

    if not CONFIG_FILE.exists():
        return []

    with open(CONFIG_FILE) as f:
        config = yaml.safe_load(f) or {}

    # Filter out non-environment keys (e.g., 'project' contains Pulumi settings)
    reserved_keys = {"project"}
    environments = [key for key in config.keys() if key not in reserved_keys]
    
    return environments
