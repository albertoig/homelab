"""Pulumi infrastructure code for kseed k3s cluster."""

import os

import pulumi
import pulumi.config as config
import pulumi_kubernetes as k8s
import yaml
from pathlib import Path

from kseed.infra.components import ComponentRegistry


def get_config_value(key: str, default: str = None) -> str:
    """Get configuration value from Pulumi config or environment."""
    try:
        # Use the config object's get method which returns None if not found
        return config.Config().get(key) or os.environ.get(key, default or "")
    except Exception:
        return os.environ.get(key, default or "")


def get_kseed_config(environment: str) -> dict:
    """Load KSeed configuration from ~/.kseed/config.
    
    Args:
        environment: The environment name (e.g., 'dev', 'prod').
        
    Returns:
        Dictionary containing the configuration for the environment.
    """
    config_path = Path.home() / ".kseed" / "config"
    
    if not config_path.exists():
        return {}
    
    with open(config_path) as f:
        all_config = yaml.safe_load(f) or {}
    
    return all_config.get(environment, {})


def get_components_config(environment: str) -> list[dict]:
    """Get the components configuration from KSeed config.
    
    Args:
        environment: The environment name.
        
    Returns:
        List of component configurations.
    """
    kseed_config = get_kseed_config(environment)
    return kseed_config.get("components", [])


def create_kubernetes_provider(kubeconfig_content: str | None = None) -> k8s.Provider:
    """Create a Kubernetes provider with the given kubeconfig."""
    if kubeconfig_content:
        return k8s.Provider(
            "k8s-provider",
            kubeconfig=kubeconfig_content,
        )
    else:
        # Try to get from environment
        kubeconfig_env = os.environ.get("KUBECONFIG")
        if kubeconfig_env:
            # Check if it's content or a path
            if os.path.exists(kubeconfig_env):
                with open(kubeconfig_env) as f:
                    kubeconfig_content = f.read()
                return k8s.Provider("k8s-provider", kubeconfig=kubeconfig_content)
            else:
                return k8s.Provider("k8s-provider", kubeconfig=kubeconfig_env)

        # Use in-cluster configuration
        return k8s.Provider("k8s-provider")


def create_namespace(name: str, provider: k8s.Provider) -> k8s.core.v1.Namespace:
    """Create a Kubernetes namespace."""
    return k8s.core.v1.Namespace(
        f"{name}-namespace",
        metadata=k8s.meta.v1.ObjectMetaArgs(
            name=name,
            labels={
                "app.kubernetes.io/name": name,
                "app.kubernetes.io/managed-by": "pulumi",
            },
        ),
        opts=pulumi.ResourceOptions(provider=provider),
    )


def create_infrastructure(environment: str = "dev") -> None:
    """Create the full infrastructure for the given environment.
    
    This function reads the component configuration from ~/.kseed/config
    and deploys each component in the correct order based on dependencies.
    
    Example ~/.kseed/config:
        dev:
          kubeconfig_path: "~/.kube/config"
          kubeconfig_context: "k3s-dev"
          components:
            - name: "metallb"
              config:
                address_pool: "192.168.1.100-192.168.1.200"
                version: "4.0.0"
                namespace: "metallb-system"
                mode: "layer2"
    """
    # Get configuration
    kubeconfig_content = get_config_value("kubeconfig")
    
    # Get KSeed config for component definitions
    get_kseed_config(environment)
    
    # Create provider
    provider = create_kubernetes_provider(kubeconfig_content)
    
    # Get components configuration
    components_config = get_components_config(environment)
    
    if not components_config:
        pulumi.warn("No components configured in ~/.kseed/config")
    
    # Get list of component names to deploy
    component_names = [c.get("name") for c in components_config if c.get("name")]
    
    # Resolve deployment order based on dependencies
    deployment_order = ComponentRegistry.resolve_deployment_order(component_names)
    
    # Create a mapping of component configs
    component_config_map = {c.get("name"): c.get("config", {}) for c in components_config}
    
    # Track deployed resources for export
    deployed_resources = {}
    
    # Deploy components in order
    for component_name in deployment_order:
        try:
            component = ComponentRegistry.get(component_name)
            component_config = component_config_map.get(component_name, {})
            
            # Validate config
            if not component.validate_config(component_config):
                raise ValueError(f"Invalid configuration for component '{component_name}'")
            
            # Deploy the component
            result = component.deploy(provider, component_config)
            
            # Store result
            deployed_resources[component_name] = result
            
        except KeyError as e:
            pulumi.warn(f"Component '{component_name}' not found: {e}")
        except Exception as e:
            raise RuntimeError(f"Failed to deploy component '{component_name}': {e}")
    
    # Export outputs
    pulumi.export("environment", environment)
    pulumi.export("deployed_components", list(deployed_resources.keys()))
    
    # Export component-specific outputs
    for component_name, resource in deployed_resources.items():
        if hasattr(resource, 'status'):
            # Export status for Helm charts
            export_name = f"{component_name}_status"
            pulumi.export(
                export_name,
                resource.status.apply(lambda s: str(s) if s else "deployed")
            )


# Entry point that can be called from __main__
if __name__ == "__main__":
    create_infrastructure()
