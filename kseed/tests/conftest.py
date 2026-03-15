"""Pytest configuration and fixtures for kseed tests."""

import os
import tempfile
from pathlib import Path
from typing import Any
from unittest.mock import patch

import pytest
import yaml


@pytest.fixture
def temp_kseed_dir(monkeypatch: pytest.MonkeyPatch) -> Path:
    """Create a temporary directory for kseed config and state."""
    with tempfile.TemporaryDirectory() as tmpdir:
        kseed_dir = Path(tmpdir)
        monkeypatch.setattr("kseed.config.manager.KSEED_DIR", kseed_dir)
        monkeypatch.setattr("kseed.config.manager.CONFIG_FILE", kseed_dir / "config")
        monkeypatch.setattr("kseed.config.manager.STATE_DIR", kseed_dir / "statefiles")
        yield kseed_dir


@pytest.fixture
def sample_kubeconfig() -> dict[str, Any]:
    """Sample kubeconfig for testing."""
    return {
        "apiVersion": "v1",
        "kind": "Config",
        "contexts": [
            {"name": "dev-cluster", "context": {"cluster": "dev-cluster", "user": "admin"}},
            {"name": "prod-cluster", "context": {"cluster": "prod-cluster", "user": "admin"}},
        ],
        "current-context": "dev-cluster",
        "clusters": [
            {"name": "dev-cluster", "cluster": {"server": "https://dev.example.com:6443"}},
            {"name": "prod-cluster", "cluster": {"server": "https://prod.example.com:6443"}},
        ],
        "users": [
            {"name": "admin", "user": {"token": "test-token"}},
        ],
    }


@pytest.fixture
def kubeconfig_file(temp_kseed_dir: Path, sample_kubeconfig: dict[str, Any]) -> Path:
    """Create a temporary kubeconfig file."""
    kubeconfig_path = temp_kseed_dir / "kubeconfig"
    with open(kubeconfig_path, "w") as f:
        yaml.safe_dump(sample_kubeconfig, f)
    return kubeconfig_path


@pytest.fixture
def mock_console_print(monkeypatch: pytest.MonkeyPatch):
    """Mock rich console print to capture output."""
    from unittest.mock import MagicMock

    mock_print = MagicMock()
    monkeypatch.setattr("kseed.config.manager.console.print", mock_print)
    return mock_print
