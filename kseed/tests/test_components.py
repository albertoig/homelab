"""Unit tests for kseed infra components."""

from unittest.mock import MagicMock, patch


from kseed.infra.components.registry import ComponentRegistry


class TestComponentRegistryClassMethods:
    """Tests for ComponentRegistry class methods."""

    def test_get_returns_cached_instance(self) -> None:
        """Test that get returns cached instance."""
        mock_instance = MagicMock()
        ComponentRegistry._components = {"test": MagicMock(return_value=mock_instance)}
        ComponentRegistry._instances = {"test": mock_instance}
        
        result = ComponentRegistry.get("test")
        
        assert result == mock_instance

    def test_get_creates_new_instance(self) -> None:
        """Test that get creates new instance if not cached."""
        mock_instance = MagicMock()
        mock_class = MagicMock(return_value=mock_instance)
        
        ComponentRegistry._components = {"test": mock_class}
        ComponentRegistry._instances = {}
        
        result = ComponentRegistry.get("test")
        
        assert result == mock_instance
        mock_class.assert_called_once()

    def test_list_available_returns_component_names(self) -> None:
        """Test list_available returns list of registered components."""
        ComponentRegistry._components = {
            "metallb": MagicMock(),
            "ingress": MagicMock(),
            "storage": MagicMock()
        }
        
        result = ComponentRegistry.list_available()
        
        assert len(result) == 3
        assert "metallb" in result
        assert "ingress" in result
        assert "storage" in result

    def test_get_dependencies_calls_get(self) -> None:
        """Test get_dependencies calls get and returns dependencies."""
        mock_component = MagicMock()
        mock_component.dependencies = ["dep1", "dep2"]
        
        with patch.object(ComponentRegistry, 'get', return_value=mock_component):
            result = ComponentRegistry.get_dependencies("test-component")
            
        assert result == ["dep1", "dep2"]

    def test_resolve_deployment_order_simple(self) -> None:
        """Test resolve_deployment_order with simple case."""
        # Create mock components with dependencies
        comp_a = MagicMock()
        comp_a.name = "a"
        comp_a.dependencies = []
        
        comp_b = MagicMock()
        comp_b.name = "b"
        comp_b.dependencies = ["a"]
        
        ComponentRegistry._components = {
            "a": lambda: comp_a,
            "b": lambda: comp_b
        }
        ComponentRegistry._instances = {}
        
        result = ComponentRegistry.resolve_deployment_order(["b", "a"])
        
        # a should come before b since b depends on a
        assert result.index("a") < result.index("b")

    def test_resolve_deployment_order_empty_list(self) -> None:
        """Test resolve_deployment_order with empty list."""
        ComponentRegistry._components = {}
        
        result = ComponentRegistry.resolve_deployment_order([])
        
        assert result == []

    def test_resolve_deployment_order_single_component(self) -> None:
        """Test resolve_deployment_order with single component."""
        comp_a = MagicMock()
        comp_a.name = "a"
        comp_a.dependencies = []
        
        ComponentRegistry._components = {"a": lambda: comp_a}
        
        result = ComponentRegistry.resolve_deployment_order(["a"])
        
        assert result == ["a"]
