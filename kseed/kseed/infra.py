"""Pulumi infrastructure code for kseed k3s cluster."""

import os

import pulumi
import pulumi_kubernetes as k8s
import pulumi_kubernetes.helm.v3 as helm


def get_config_value(key: str, default: str = None) -> str:
    """Get configuration value from Pulumi config or environment."""
    try:
        return pulumi.get_config(key)
    except pulumi.config.ConfigKeyNotFoundError:
        return os.environ.get(key, default or "")


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


def install_nginx_ingress(
    namespace: str,
    provider: k8s.Provider,
    chart_version: str = "4.10.0",
) -> helm.Chart:
    """Install nginx-ingress Helm chart."""
    return helm.Chart(
        "nginx-ingress",
        chart="ingress-nginx",
        version=chart_version,
        fetch_opts=helm.FetchOpts(
            repo="https://kubernetes.github.io/ingress-nginx",
        ),
        namespace=namespace,
        values={
            "controller": {
                "service": {
                    "type": "LoadBalancer",
                },
            },
        },
        opts=pulumi.ResourceOptions(provider=provider),
    )


def create_infrastructure(environment: str = "dev") -> None:
    """Create the full infrastructure for the given environment."""
    # Get stack reference
    stack_name = pulumi.get_stack()

    # Get configuration
    kubeconfig_content = get_config_value("kubeconfig")

    # Create provider
    provider = create_kubernetes_provider(kubeconfig_content)

    # Namespace configuration
    namespace_name = get_config_value("namespace", "default")
    namespace = create_namespace(namespace_name, provider)

    # Install nginx-ingress
    nginx_ingress = install_nginx_ingress(namespace_name, provider)

    # Export outputs
    pulumi.export("namespace", namespace.metadata.name)
    pulumi.export(
        "nginx_ingress_external_ip",
        nginx_ingress.status.apply(
            lambda status: (
                status.load_balancer.ingress[0].ip
                if status and status.load_balancer
                else "pending"
            )
        ),
    )


# Entry point that can be called from __main__
if __name__ == "__main__":
    create_infrastructure()
