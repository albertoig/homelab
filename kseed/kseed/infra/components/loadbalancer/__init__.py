"""Load balancer components for KSeed.

This module provides load balancer implementations including MetalLB.
"""

from kseed.infra.components.registry import ComponentRegistry
from kseed.infra.components.loadbalancer.metallb import MetalLBComponent

# Register load balancer components
ComponentRegistry.register(MetalLBComponent)

__all__ = [
    "MetalLBComponent",
]
