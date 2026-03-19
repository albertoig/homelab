"""Component registry for KSeed infrastructure components.

This module provides a registry for discovering and managing infrastructure
components. Components can be registered manually or auto-discovered.
"""

from typing import Any, Type

from kseed.infra.components.base import BaseComponent


class ComponentRegistry:
    """Registry for managing infrastructure components.
    
    The registry maintains a mapping of component names to their classes.
    Components can be registered manually or discovered automatically.
    
    Usage:
        # Register a component
        ComponentRegistry.register(MyComponent)
        
        # Get a component instance
        component = ComponentRegistry.get("my-component")
        
        # List available components
        available = ComponentRegistry.list_available()
    """
    
    _components: dict[str, Type[BaseComponent]] = {}
    _instances: dict[str, BaseComponent] = {}
    
    @classmethod
    def register(cls, component_class: Type[BaseComponent]) -> None:
        """Register a component class.
        
        Args:
            component_class: The component class to register.
            
        Raises:
            TypeError: If the component_class is not a subclass of BaseComponent.
        """
        if not issubclass(component_class, BaseComponent):
            raise TypeError(
                f"Component must be a subclass of BaseComponent, "
                f"got {component_class.__name__}"
            )
        
        cls._components[component_class.name] = component_class
    
    @classmethod
    def get(cls, name: str) -> BaseComponent:
        """Get a component instance by name.
        
        Args:
            name: The component name.
            
        Returns:
            An instance of the component.
            
        Raises:
            KeyError: If the component is not registered.
        """
        # Return cached instance if available
        if name in cls._instances:
            return cls._instances[name]
        
        if name not in cls._components:
            raise KeyError(f"Component '{name}' is not registered. "
                          f"Available: {list(cls._components.keys())}")
        
        # Create new instance and cache it
        instance = cls._components[name]()
        cls._instances[name] = instance
        return instance
    
    @classmethod
    def list_available(cls) -> list[str]:
        """List all available component names.
        
        Returns:
            List of registered component names.
        """
        return list(cls._components.keys())
    
    @classmethod
    def get_dependencies(cls, name: str) -> list[str]:
        """Get the dependencies for a component.
        
        Args:
            name: The component name.
            
        Returns:
            List of dependency component names.
        """
        component = cls.get(name)
        return component.dependencies
    
    @classmethod
    def resolve_deployment_order(cls, components: list[str]) -> list[str]:
        """Resolve the deployment order based on dependencies.
        
        Args:
            components: List of component names to deploy.
            
        Returns:
            Ordered list of components to deploy.
        """
        # Build dependency graph
        resolved: list[str] = []
        seen: set[str] = set()
        
        def visit(name: str):
            if name in seen:
                return
            seen.add(name)
            
            # Get dependencies
            try:
                deps = cls.get_dependencies(name)
            except KeyError:
                deps = []
            
            # Visit dependencies first
            for dep in deps:
                if dep in components:
                    visit(dep)
            
            # Add this component
            if name in components:
                resolved.append(name)
        
        # Visit all components
        for component in components:
            visit(component)
        
        return resolved
    
    @classmethod
    def clear_cache(cls) -> None:
        """Clear the component instance cache.
        
        This is useful for testing or when components need to be
        re-initialized.
        """
        cls._instances.clear()


def register_components() -> None:
    """Auto-register all built-in components.
    
    This function imports all component modules to trigger their
    registration. It should be called during module initialization.
    """
    # Import loadbalancer components
    from kseed.infra.components.loadbalancer import metallb
    
    # Import other component categories as they're added
    # from kseed.infra.components.networking import ...
    # from kseed.infra.components.storage import ...
