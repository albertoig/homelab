"""Unit tests for kseed diagnose functionality."""

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import yaml


class TestClusterHealth:
    """Tests for the ClusterHealth dataclass."""

    def test_cluster_health_defaults(self) -> None:
        """Test ClusterHealth default values."""
        from kseed.diagnose.checker import ClusterHealth

        health = ClusterHealth(
            environment="dev",
            cluster_reachable=False,
            has_permissions=False,
            can_install_helm=False,
        )

        assert health.environment == "dev"
        assert health.cluster_reachable is False
        assert health.has_permissions is False
        assert health.can_install_helm is False
        assert health.cluster_info is None
        assert health.error_message is None

    def test_cluster_health_with_values(self) -> None:
        """Test ClusterHealth with all values set."""
        from kseed.diagnose.checker import ClusterHealth

        health = ClusterHealth(
            environment="prod",
            cluster_reachable=True,
            has_permissions=True,
            can_install_helm=True,
            cluster_info="k3s version: v1.32.0+k3s1",
            error_message=None,
        )

        assert health.environment == "prod"
        assert health.cluster_reachable is True
        assert health.has_permissions is True
        assert health.can_install_helm is True
        assert health.cluster_info == "k3s version: v1.32.0+k3s1"
        assert health.error_message is None


class TestGetAllConfiguredEnvironments:
    """Tests for get_all_configured_environments function."""

    def test_returns_empty_list_when_no_config_file(self) -> None:
        """Test returns empty list when config file doesn't exist."""
        from kseed.diagnose.checker import get_all_configured_environments
        from kseed import config as config_module

        # Save original
        original = config_module.manager.CONFIG_FILE

        # Create a non-existent path
        config_module.manager.CONFIG_FILE = Path("/non/existent/path/config")

        try:
            from kseed.diagnose.checker import get_all_configured_environments  # noqa: F811
            import importlib
            import kseed.diagnose.checker as checker_module

            importlib.reload(checker_module)
            from kseed.diagnose.checker import get_all_configured_environments  # noqa: F811

            result = get_all_configured_environments()
            assert result == []
        finally:
            config_module.manager.CONFIG_FILE = original

    def test_returns_environments_from_config(self, tmp_path: Path) -> None:
        """Test returns list of environments from config."""
        # Create a real config file
        config_file = tmp_path / "config"
        config_data = {"dev": {}, "prod": {"kubeconfig_path": "/test"}}
        config_file.write_text(yaml.dump(config_data))

        # Patch the CONFIG_FILE to point to our temp file
        from kseed import config as config_module

        original_config_file = config_module.manager.CONFIG_FILE

        try:
            config_module.manager.CONFIG_FILE = config_file
            from kseed.diagnose.checker import get_all_configured_environments  # noqa: F811
            import importlib
            import kseed.diagnose.checker as checker_module

            importlib.reload(checker_module)
            from kseed.diagnose.checker import get_all_configured_environments  # noqa: F811

            result = get_all_configured_environments()
            assert set(result) == {"dev", "prod"}
        finally:
            config_module.manager.CONFIG_FILE = original_config_file


class TestCheckClusterHealth:
    """Tests for check_cluster_health function."""

    @pytest.fixture
    def kubeconfig_file(self, tmp_path: Path) -> Path:
        """Create a valid kubeconfig file."""
        kubeconfig = {
            "apiVersion": "v1",
            "kind": "Config",
            "contexts": [
                {
                    "name": "test-context",
                    "context": {"cluster": "test-cluster", "user": "test-user"},
                }
            ],
            "current-context": "test-context",
            "clusters": [{"name": "test-cluster", "cluster": {"server": "https://localhost:6443"}}],
            "users": [{"name": "test-user", "user": {"token": "test-token"}}],
        }
        config_path = tmp_path / "kubeconfig"
        config_path.write_text(yaml.dump(kubeconfig))
        return config_path

    def test_check_cluster_health_returns_result(self, kubeconfig_file: Path) -> None:
        """Test check_cluster_health returns a ClusterHealth result."""
        from kseed.diagnose.checker import check_cluster_health, ClusterHealth
        import kseed.diagnose.checker as checker_module
        from kubernetes import client

        # Mock _load_kubeconfig to avoid needing real kubeconfig
        with patch.object(checker_module, "_load_kubeconfig") as mock_load:
            mock_load.return_value = MagicMock()

            # Mock the API classes
            mock_version = MagicMock()
            mock_version.get_code.return_value = MagicMock(git_version="v1.32.0+k3s1")

            mock_core = MagicMock()
            mock_apps = MagicMock()

            with patch.object(client, "VersionApi", return_value=mock_version):
                with patch.object(client, "CoreV1Api", return_value=mock_core):
                    with patch.object(client, "AppsV1Api", return_value=mock_apps):
                        result = check_cluster_health("dev", kubeconfig_file, "test-context")

                        assert isinstance(result, ClusterHealth)
                        assert result.environment == "dev"

    def test_cluster_unreachable_error(self, kubeconfig_file: Path) -> None:
        """Test cluster unreachable error message."""
        from kseed.diagnose.checker import check_cluster_health, ClusterHealth
        import kseed.diagnose.checker as checker_module
        from kubernetes import client
        from kubernetes.client.exceptions import ApiException

        with patch.object(checker_module, "_load_kubeconfig") as mock_load:
            mock_load.return_value = MagicMock()

            # Make version API raise an ApiException
            mock_version = MagicMock()
            mock_version.get_code.side_effect = ApiException(reason="Connection refused")

            mock_core = MagicMock()
            mock_apps = MagicMock()

            with patch.object(client, "VersionApi", return_value=mock_version):
                with patch.object(client, "CoreV1Api", return_value=mock_core):
                    with patch.object(client, "AppsV1Api", return_value=mock_apps):
                        result = check_cluster_health("dev", kubeconfig_file, "test-context")

                        assert isinstance(result, ClusterHealth)
                        assert result.cluster_reachable is False
                        assert result.error_message is not None
                        assert "Cannot reach cluster" in result.error_message

    def test_permissions_denied_error(self, kubeconfig_file: Path) -> None:
        """Test permissions denied error message."""
        from kseed.diagnose.checker import check_cluster_health, ClusterHealth
        import kseed.diagnose.checker as checker_module
        from kubernetes import client
        from kubernetes.client.exceptions import ApiException

        with patch.object(checker_module, "_load_kubeconfig") as mock_load:
            mock_load.return_value = MagicMock()

            # Version succeeds but namespace list fails
            mock_version = MagicMock()
            mock_version.get_code.return_value = MagicMock(git_version="v1.32.0+k3s1")

            mock_core = MagicMock()
            mock_core.list_namespace.side_effect = ApiException(reason="Unauthorized")

            mock_apps = MagicMock()

            with patch.object(client, "VersionApi", return_value=mock_version):
                with patch.object(client, "CoreV1Api", return_value=mock_core):
                    with patch.object(client, "AppsV1Api", return_value=mock_apps):
                        result = check_cluster_health("dev", kubeconfig_file, "test-context")

                        assert isinstance(result, ClusterHealth)
                        assert result.cluster_reachable is True
                        assert result.has_permissions is False
                        assert result.error_message is not None
                        assert "Permission denied" in result.error_message

    def test_helm_forbidden_error(self, kubeconfig_file: Path) -> None:
        """Test helm forbidden error message."""
        from kseed.diagnose.checker import check_cluster_health, ClusterHealth
        import kseed.diagnose.checker as checker_module
        from kubernetes import client
        from kubernetes.client.exceptions import ApiException

        with patch.object(checker_module, "_load_kubeconfig") as mock_load:
            mock_load.return_value = MagicMock()

            mock_version = MagicMock()
            mock_version.get_code.return_value = MagicMock(git_version="v1.32.0+k3s1")

            mock_core = MagicMock()

            # Helm check fails with Forbidden
            mock_apps = MagicMock()
            mock_apps.list_namespaced_deployment.side_effect = ApiException(reason="Forbidden")

            with patch.object(client, "VersionApi", return_value=mock_version):
                with patch.object(client, "CoreV1Api", return_value=mock_core):
                    with patch.object(client, "AppsV1Api", return_value=mock_apps):
                        result = check_cluster_health("dev", kubeconfig_file, "test-context")

                        assert isinstance(result, ClusterHealth)
                        assert result.cluster_reachable is True
                        assert result.has_permissions is True
                        assert result.can_install_helm is False
                        assert result.error_message is not None
                        assert "Cannot install Helm" in result.error_message

    def test_helm_non_forbidden_error(self, kubeconfig_file: Path) -> None:
        """Test helm allowed when error is not Forbidden."""
        from kseed.diagnose.checker import check_cluster_health, ClusterHealth
        import kseed.diagnose.checker as checker_module
        from kubernetes import client
        from kubernetes.client.exceptions import ApiException

        with patch.object(checker_module, "_load_kubeconfig") as mock_load:
            mock_load.return_value = MagicMock()

            mock_version = MagicMock()
            mock_version.get_code.return_value = MagicMock(git_version="v1.32.0+k3s1")

            mock_core = MagicMock()

            # Helm check fails with non-Forbidden error (e.g., Not Found)
            mock_apps = MagicMock()
            mock_apps.list_namespaced_deployment.side_effect = ApiException(reason="Not Found")

            with patch.object(client, "VersionApi", return_value=mock_version):
                with patch.object(client, "CoreV1Api", return_value=mock_core):
                    with patch.object(client, "AppsV1Api", return_value=mock_apps):
                        result = check_cluster_health("dev", kubeconfig_file, "test-context")

                        assert isinstance(result, ClusterHealth)
                        assert result.can_install_helm is True

    def test_general_exception_error(self, kubeconfig_file: Path) -> None:
        """Test general exception handling."""
        from kseed.diagnose.checker import check_cluster_health, ClusterHealth
        import kseed.diagnose.checker as checker_module
        from kubernetes import client

        with patch.object(checker_module, "_load_kubeconfig") as mock_load:
            mock_load.return_value = MagicMock()

            # Make the version API raise a general exception
            mock_version = MagicMock()
            mock_version.get_code.side_effect = RuntimeError("Something went wrong")

            with patch.object(client, "VersionApi", return_value=mock_version):
                result = check_cluster_health("dev", kubeconfig_file, "test-context")

                assert isinstance(result, ClusterHealth)
                assert result.error_message is not None


class TestLoadKubeconfig:
    """Tests for _load_kubeconfig function."""

    @pytest.fixture
    def kubeconfig_file(self, tmp_path: Path) -> Path:
        """Create a valid kubeconfig file."""
        kubeconfig = {
            "apiVersion": "v1",
            "kind": "Config",
            "contexts": [
                {
                    "name": "test-context",
                    "context": {"cluster": "test-cluster", "user": "test-user"},
                }
            ],
            "current-context": "test-context",
            "clusters": [{"name": "test-cluster", "cluster": {"server": "https://localhost:6443"}}],
            "users": [{"name": "test-user", "user": {"token": "test-token"}}],
        }
        config_path = tmp_path / "kubeconfig"
        config_path.write_text(yaml.dump(kubeconfig))
        return config_path

    def test_raises_error_when_context_not_found(self, kubeconfig_file: Path) -> None:
        """Test raises ValueError when context doesn't exist."""
        from kseed.diagnose.checker import _load_kubeconfig

        with pytest.raises(ValueError, match="not found"):
            _load_kubeconfig(kubeconfig_file, "non-existent-context")

    def test_loads_kubeconfig(self, kubeconfig_file: Path) -> None:
        """Test loads kubeconfig and returns ApiClient."""
        from kseed.diagnose.checker import _load_kubeconfig

        # Mock the kubernetes config loading to avoid needing real cluster
        with patch("kubernetes.config.load_kube_config"):
            result = _load_kubeconfig(kubeconfig_file, "test-context")
            assert result is not None


class TestHealthStatus:
    """Tests for HealthStatus enum."""

    def test_health_status_values(self) -> None:
        """Test HealthStatus enum values."""
        from kseed.diagnose.checker import HealthStatus

        assert HealthStatus.HEALTHY.value == "healthy"
        assert HealthStatus.UNHEALTHY.value == "unhealthy"
        assert HealthStatus.UNKNOWN.value == "unknown"
