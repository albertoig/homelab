"""KSeed infrastructure components.

This module provides a plugin-based architecture for infrastructure components.
Components can be registered and discovered at runtime.

Usage:
    from kseed.infra.components import ComponentRegistry, BaseComponent

    # List available components
    available = ComponentRegistry.list_available()

    # Get and deploy a component
    component = ComponentRegistry.get("metallb")
    component.deploy(provider, config)
"""

from kseed.infra.components.base import BaseComponent
from kseed.infra.components.registry import (
    ComponentRegistry,
    register_components,
)

# Auto-register all built-in components
register_components()

__all__ = [
    "BaseComponent",
    "ComponentRegistry",
    "register_components",
]
