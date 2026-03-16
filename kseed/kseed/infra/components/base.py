"""Base component interface for KSeed infrastructure components."""

from abc import ABC, abstractmethod
from typing import Any


class BaseComponent(ABC):
    """Abstract base class for all KSeed infrastructure components.

    Components are the building blocks of KSeed infrastructure. Each component
    represents a deployable piece of infrastructure (e.g., MetalLB, NGINX Ingress,
    CertManager, etc.).

    Attributes:
        name: Unique identifier for the component.
        dependencies: List of component names that must be deployed before this one.
    """

    name: str = "base"
    """Unique identifier for the component."""

    dependencies: list[str] = []
    """List of component names that must be deployed before this one."""

    @abstractmethod
    def deploy(self, provider: Any, config: dict[str, Any]) -> Any:
        """Deploy the component using the given Kubernetes provider and configuration.

        Args:
            provider: The Pulumi Kubernetes provider.
            config: Component-specific configuration dictionary.

        Returns:
            The Pulumi resource created by the component.
        """
        pass

    @abstractmethod
    def get_outputs(self) -> dict[str, Any]:
        """Get the outputs from the deployed component.

        Returns:
            Dictionary of output values that can be exported.
        """
        pass

    def validate_config(self, config: dict[str, Any]) -> bool:
        """Validate the component configuration.

        Args:
            config: Configuration dictionary to validate.

        Returns:
            True if configuration is valid, False otherwise.
        """
        return True
