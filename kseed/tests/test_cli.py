"""Unit tests for kseed CLI commands."""

from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
from typer.testing import CliRunner

from kseed.cli.commands import app


@pytest.fixture
def runner() -> CliRunner:
    """Create a Typer CLI test runner."""
    return CliRunner()


class TestStatusCommand:
    """Tests for the status command."""

    @patch("kseed.cli.commands.kseed_config.get_state_path")
    @patch("kseed.cli.commands.KSeedConfig")
    def test_status_shows_configured_environment(
        self, mock_config_class: MagicMock, mock_get_state: MagicMock, runner: CliRunner
    ) -> None:
        """Test status shows configured environment details."""
        mock_config = MagicMock()
        mock_config.kubeconfig_path = Path("/test/kubeconfig")
        mock_config.kubeconfig_context = "dev-cluster"
        mock_config.project_name = "homelab"
        mock_config.project_runtime = "python"
        mock_config.project_main = "kseed/"
        mock_config.components = []
        mock_config.load.return_value = {
            "kubeconfig_path": "/test/kubeconfig",
            "kubeconfig_context": "dev-cluster",
        }
        mock_config_class.return_value = mock_config
        mock_get_state.return_value = Path("/test/state/dev.state")

        result = runner.invoke(app, ["status", "dev"])

        assert result.exit_code == 0
        assert "dev" in result.output
        assert "/test/kubeconfig" in result.output
        assert "dev-cluster" in result.output

    @patch("kseed.cli.commands.kseed_config.get_state_path")
    @patch("kseed.cli.commands.KSeedConfig")
    def test_status_shows_not_configured(
        self, mock_config_class: MagicMock, mock_get_state: MagicMock, runner: CliRunner
    ) -> None:
        """Test status shows Not configured when no config exists."""
        mock_config = MagicMock()
        mock_config.kubeconfig_path = None
        mock_config.kubeconfig_context = None
        mock_config.project_name = "homelab"
        mock_config.project_runtime = "python"
        mock_config.project_main = "kseed/"
        mock_config.components = []
        mock_config.load.return_value = {}
        mock_config_class.return_value = mock_config
        mock_get_state.return_value = Path("/test/state/dev.state")

        result = runner.invoke(app, ["status", "dev"])

        assert result.exit_code == 0
        assert "Not configured" in result.output


class TestUpCommand:
    """Tests for the up command."""

    @patch("kseed.cli.commands.run_up")
    @patch("kseed.cli.commands.KSeedConfig")
    def test_up_requires_configured_environment(
        self,
        mock_config_class: MagicMock,
        mock_run_up: MagicMock,
        runner: CliRunner,
    ) -> None:
        """Test that up fails if environment is not configured."""
        mock_config = MagicMock()
        mock_config.kubeconfig_path = None
        mock_config.kubeconfig_context = None
        mock_config.load.return_value = {}
        mock_config_class.return_value = mock_config

        result = runner.invoke(app, ["up", "dev"])

        assert result.exit_code == 1
        assert "not configured" in result.output.lower()


class TestDestroyCommand:
    """Tests for the destroy command."""

    @patch("kseed.cli.commands.run_destroy")
    @patch("kseed.cli.commands.KSeedConfig")
    def test_destroy_requires_configured_environment(
        self,
        mock_config_class: MagicMock,
        mock_run_destroy: MagicMock,
        runner: CliRunner,
    ) -> None:
        """Test that destroy fails if environment is not configured."""
        mock_config = MagicMock()
        mock_config.kubeconfig_path = None
        mock_config.kubeconfig_context = None
        mock_config.load.return_value = {}
        mock_config_class.return_value = mock_config

        result = runner.invoke(app, ["destroy", "dev"])

        assert result.exit_code == 1
        assert "not configured" in result.output.lower()
