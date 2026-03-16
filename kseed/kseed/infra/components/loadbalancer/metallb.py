"""MetalLB load balancer component for KSeed.

MetalLB is a bare-metal load balancer for Kubernetes. This component
provides Layer 2 (ARP) and Layer 3 (BGP) load balancing modes.
"""

from typing import Any

import pulumi
import pulumi_kubernetes as k8s
import pulumi_kubernetes.helm.v3 as helm

from kseed.infra.components.base import BaseComponent


class MetalLBComponent(BaseComponent):
    """MetalLB load balancer component.
    
    MetalLB provides network load-balancing for bare metal Kubernetes clusters.
    It supports two modes:
    - Layer 2 (ARP/NDP): Uses ARP/NDP to announce the service IP
    - Layer 3 (BGP): Uses BGP peering for more advanced routing
    
    Configuration:
        - address_pool: IP address range for services (e.g., "192.168.1.100-192.168.1.200")
        - version: Helm chart version (default: "4.0.0")
        - namespace: Kubernetes namespace to deploy to (default: "metallb-system")
        - mode: Load balancing mode - "layer2" or "bgp" (default: "layer2")
    
    Example config:
        name: "metallb"
        config:
          address_pool: "192.168.1.100-192.168.1.200"
          version: "4.0.0"
          namespace: "metallb-system"
          mode: "layer2"
    """
    
    name = "metallb"
    """Unique component name."""
    
    dependencies = []
    """MetalLB has no dependencies on other components."""
    
    def __init__(self):
        self._chart: helm.Chart | None = None
        self._namespace: k8s.core.v1.Namespace | None = None
        self._address_pool: str = "192.168.1.100-192.168.1.200"
        self._version: str = "4.0.0"
        self._namespace_name: str = "metallb-system"
        self._mode: str = "layer2"
        self._config: dict[str, Any] = {}
    
    def deploy(self, provider: k8s.Provider, config: dict[str, Any]) -> helm.Chart:
        """Deploy MetalLB using Helm.
        
        Args:
            provider: The Pulumi Kubernetes provider.
            config: MetalLB configuration dictionary.
            
        Returns:
            The MetalLB Helm chart.
        """
        # Extract configuration
        self._config = config
        self._address_pool = config.get("address_pool", self._address_pool)
        self._version = config.get("version", self._version)
        self._namespace_name = config.get("namespace", self._namespace_name)
        self._mode = config.get("mode", self._mode)
        
        # Validate mode
        if self._mode not in ("layer2", "bgp"):
            raise ValueError(f"Invalid mode '{self._mode}'. Must be 'layer2' or 'bgp'")
        
        # Create namespace
        self._namespace = k8s.core.v1.Namespace(
            f"{self._namespace_name}-namespace",
            metadata=k8s.meta.v1.ObjectMetaArgs(
                name=self._namespace_name,
                labels={
                    "app.kubernetes.io/name": "metallb",
                    "app.kubernetes.io/managed-by": "pulumi",
                },
            ),
            opts=pulumi.ResourceOptions(provider=provider),
        )
        
        # Determine Helm values based on mode
        if self._mode == "layer2":
            values = self._get_layer2_config()
        else:
            values = self._get_bgp_config()
        
        # Deploy MetalLB via Helm
        self._chart = helm.Chart(
            "metallb",
            chart="metallb",
            version=self._version,
            fetch_opts=helm.FetchOpts(
                repo="https://metallb.github.io/metallb",
            ),
            namespace=self._namespace_name,
            values=values,
            opts=pulumi.ResourceOptions(
                provider=provider,
                depends_on=[self._namespace],
            ),
        )
        
        return self._chart
    
    def _get_layer2_config(self) -> dict[str, Any]:
        """Get configuration for Layer 2 mode."""
        return {
            "configInline": {
                "address-pools": [
                    {
                        "name": "default",
                        "protocol": "layer2",
                        "addresses": [self._address_pool],
                        "auto-assign": True,
                    }
                ]
            }
        }
    
    def _get_bgp_config(self) -> dict[str, Any]:
        """Get configuration for BGP mode."""
        # For BGP, we need routerPeerAddress and ASN configuration
        bgp_peers = self._config.get("bgp_peers", [])
        
        return {
            "configInline": {
                "peers": bgp_peers,
                "bgp-advertisements": [
                    {
                        "aggregationLength": 32,
                        "aggregationLengthV6": 128,
                        "community": "",
                        "localPref": "",
                    }
                ],
            }
        }
    
    def get_outputs(self) -> dict[str, Any]:
        """Get outputs from the deployed MetalLB component.
        
        Returns:
            Dictionary of output values.
        """
        if not self._chart:
            return {}
        
        return {
            "namespace": self._namespace_name,
            "address_pool": self._address_pool,
            "mode": self._mode,
            "version": self._version,
        }
    
    def validate_config(self, config: dict[str, Any]) -> bool:
        """Validate MetalLB configuration.
        
        Args:
            config: Configuration dictionary to validate.
            
        Returns:
            True if configuration is valid.
            
        Raises:
            ValueError: If configuration is invalid.
        """
        # Validate address pool format (basic check)
        address_pool = config.get("address_pool", "")
        if address_pool and "-" not in address_pool:
            # Could be a single IP or CIDR
            if "/" not in address_pool:
                raise ValueError(
                    f"Invalid address_pool '{address_pool}'. "
                    "Expected format: '192.168.1.100-192.168.1.200' or '192.168.1.0/24'"
                )
        
        # Validate mode
        mode = config.get("mode", "layer2")
        if mode not in ("layer2", "bgp"):
            raise ValueError(f"Invalid mode '{mode}'. Must be 'layer2' or 'bgp'")
        
        # Validate version
        version = config.get("version", "4.0.0")
        if not version:
            raise ValueError("version cannot be empty")
        
        return True
