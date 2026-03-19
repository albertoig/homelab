"""Unit tests for kseed.config module."""

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import yaml

from kseed.config import (
    KSeedConfig,
    get_available_contexts,
    get_state_path,
    read_kubeconfig,
    setup_kubeconfig,
)


class TestKSeedConfig:
    """Tests for KSeedConfig class."""

    def test_init_creates_config_dir(self, temp_kseed_dir: Path) -> None:
        """Test that initializing KSeedConfig creates the config directory."""
        KSeedConfig("dev")
        assert temp_kseed_dir.exists()
        assert temp_kseed_dir.is_dir()

    def test_init_loads_existing_config(self, temp_kseed_dir: Path) -> None:
        """Test that KSeedConfig loads existing configuration."""
        # Create config file with existing data
        config_file = temp_kseed_dir / "config"
        config_data = {"dev": {"kubeconfig_path": "/test/kubeconfig", "kubeconfig_context": "dev"}}
        with open(config_file, "w") as f:
            yaml.safe_dump(config_data, f)

        config = KSeedConfig("dev")
        loaded = config.load()

        assert loaded["kubeconfig_path"] == "/test/kubeconfig"
        assert loaded["kubeconfig_context"] == "dev"

    def test_init_returns_empty_config_when_no_file(self, temp_kseed_dir: Path) -> None:
        """Test that KSeedConfig returns empty dict when no config exists."""
        config = KSeedConfig("dev")
        loaded = config.load()

        assert loaded == {}

    def test_save_config(self, temp_kseed_dir: Path) -> None:
        """Test saving configuration."""
        config = KSeedConfig("dev")
        config.save({"kubeconfig_path": "/test/kubeconfig", "kubeconfig_context": "dev"})

        # Verify file was created
        config_file = temp_kseed_dir / "config"
        assert config_file.exists()

        # Verify content
        with open(config_file) as f:
            data = yaml.safe_load(f)

        assert data["dev"]["kubeconfig_path"] == "/test/kubeconfig"
        assert data["dev"]["kubeconfig_context"] == "dev"

    def test_save_preserves_other_environments(self, temp_kseed_dir: Path) -> None:
        """Test that saving config for one environment preserves others."""
        # Create config file with prod environment
        config_file = temp_kseed_dir / "config"
        config_data = {
            "prod": {"kubeconfig_path": "/prod/kubeconfig", "kubeconfig_context": "prod"}
        }
        with open(config_file, "w") as f:
            yaml.safe_dump(config_data, f)

        # Save dev environment
        config = KSeedConfig("dev")
        config.save({"kubeconfig_path": "/dev/kubeconfig", "kubeconfig_context": "dev"})

        # Verify both environments exist
        with open(config_file) as f:
            data = yaml.safe_load(f)

        assert "prod" in data
        assert "dev" in data
        assert data["prod"]["kubeconfig_path"] == "/prod/kubeconfig"
        assert data["dev"]["kubeconfig_path"] == "/dev/kubeconfig"

    def test_get_with_default(self, temp_kseed_dir: Path) -> None:
        """Test getting config value with default."""
        config = KSeedConfig("dev")

        # Test with missing key
        result = config.get("nonexistent", "default_value")
        assert result == "default_value"

    def test_get_existing_value(self, temp_kseed_dir: Path) -> None:
        """Test getting existing config value."""
        config = KSeedConfig("dev")
        config.save({"test_key": "test_value"})

        result = config.get("test_key")
        assert result == "test_value"

    def test_set_value(self, temp_kseed_dir: Path) -> None:
        """Test setting a config value."""
        config = KSeedConfig("dev")
        config.set("test_key", "test_value")

        # Verify it was saved
        config2 = KSeedConfig("dev")
        assert config2.get("test_key") == "test_value"

    def test_kubeconfig_path_property(self, temp_kseed_dir: Path) -> None:
        """Test kubeconfig_path property."""
        config = KSeedConfig("dev")
        config.save({"kubeconfig_path": "/test/kubeconfig"})

        assert config.kubeconfig_path == Path("/test/kubeconfig")

    def test_kubeconfig_path_property_none(self, temp_kseed_dir: Path) -> None:
        """Test kubeconfig_path property returns None when not set."""
        config = KSeedConfig("dev")

        assert config.kubeconfig_path is None

    def test_kubeconfig_context_property(self, temp_kseed_dir: Path) -> None:
        """Test kubeconfig_context property."""
        config = KSeedConfig("dev")
        config.save({"kubeconfig_context": "dev-cluster"})

        assert config.kubeconfig_context == "dev-cluster"

    def test_kubeconfig_context_property_none(self, temp_kseed_dir: Path) -> None:
        """Test kubeconfig_context property returns None when not set."""
        config = KSeedConfig("dev")

        assert config.kubeconfig_context is None


class TestGetStatePath:
    """Tests for get_state_path function."""

    def test_get_state_path_creates_dir(self, temp_kseed_dir: Path) -> None:
        """Test that get_state_path creates the state directory."""
        state_path = get_state_path("dev")

        assert state_path.parent.exists()
        assert state_path.parent.is_dir()

    def test_get_state_path_returns_correct_path(self, temp_kseed_dir: Path) -> None:
        """Test that get_state_path returns correct path."""
        state_path = get_state_path("dev")

        assert state_path.parent == temp_kseed_dir / "statefiles"
        assert state_path.name == "dev.state"


class TestReadKubeconfig:
    """Tests for read_kubeconfig function."""

    def test_read_kubeconfig(self, kubeconfig_file: Path, sample_kubeconfig: dict) -> None:
        """Test reading kubeconfig file."""
        result = read_kubeconfig(kubeconfig_file)

        assert result == sample_kubeconfig

    def test_read_kubeconfig_file_not_found(self, temp_kseed_dir: Path) -> None:
        """Test reading non-existent kubeconfig raises FileNotFoundError."""
        with pytest.raises(FileNotFoundError):
            read_kubeconfig(temp_kseed_dir / "nonexistent")


class TestGetAvailableContexts:
    """Tests for get_available_contexts function."""

    def test_get_available_contexts(self, kubeconfig_file: Path) -> None:
        """Test extracting contexts from kubeconfig."""
        contexts = get_available_contexts(kubeconfig_file)

        assert contexts == ["dev-cluster", "prod-cluster"]

    def test_get_available_contexts_empty(self, temp_kseed_dir: Path) -> None:
        """Test with kubeconfig that has no contexts."""
        kubeconfig_path = temp_kseed_dir / "empty-kubeconfig"
        with open(kubeconfig_path, "w") as f:
            yaml.safe_dump({"apiVersion": "v1", "kind": "Config"}, f)

        contexts = get_available_contexts(kubeconfig_path)

        assert contexts == []


class TestSetupKubeconfig:
    """Tests for setup_kubeconfig function."""

    def test_setup_kubeconfig_already_configured(
        self,
        temp_kseed_dir: Path,
        mock_console_print: MagicMock,
    ) -> None:
        """Test setup_kubeconfig when already configured."""
        # Pre-configure
        config = KSeedConfig("dev")
        config.save({"kubeconfig_path": "/test/kubeconfig", "kubeconfig_context": "dev"})

        result = setup_kubeconfig("dev")

        assert result.kubeconfig_path == Path("/test/kubeconfig")
        assert result.kubeconfig_context == "dev"

    def test_setup_kubeconfig_file_not_found(
        self, temp_kseed_dir: Path, mock_console_print: MagicMock
    ) -> None:
        """Test setup_kubeconfig with non-existent kubeconfig file."""
        with pytest.raises(FileNotFoundError):
            setup_kubeconfig("dev", Path("/nonexistent/kubeconfig"))

    @patch("kseed.config.manager.select_kubeconfig_context")
    def test_setup_kubeconfig_success(
        self,
        mock_select_context: MagicMock,
        temp_kseed_dir: Path,
        kubeconfig_file: Path,
        mock_console_print: MagicMock,
    ) -> None:
        """Test successful kubeconfig setup."""
        mock_select_context.return_value = "dev-cluster"

        result = setup_kubeconfig("dev", kubeconfig_file)

        assert result.kubeconfig_path == kubeconfig_file
        assert result.kubeconfig_context == "dev-cluster"
