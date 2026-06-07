import os
import pytest
import requests
import yaml
from kubernetes import client, config as k8s_config
from pathlib import Path

ENV = os.environ.get("ENV", "dev")

_CONFIG_PATH = Path(__file__).parent.parent / "helmfile" / "environments" / ENV / "config.yaml"


def _load_env_config() -> dict:
    with open(_CONFIG_PATH) as f:
        return yaml.safe_load(f)


def _root_dns() -> str:
    return _load_env_config()["general"]["root_dns"]


def _url(subdomain: str) -> str:
    return f"https://{subdomain}.{_root_dns()}"


@pytest.fixture(scope="session")
def env() -> str:
    return ENV


@pytest.fixture(scope="session")
def root_dns() -> str:
    return _root_dns()


@pytest.fixture(scope="session")
def urls(root_dns) -> dict[str, str]:
    return {
        "authentik":  f"https://auth.{root_dns}",
        "grafana":    f"https://grafana.internal.{root_dns}",
        "argocd":     f"https://argocd.internal.{root_dns}",
        "longhorn":   f"https://longhorn.internal.{root_dns}",
    }


@pytest.fixture(scope="session")
def http() -> requests.Session:
    session = requests.Session()
    session.verify = True
    return session


@pytest.fixture(scope="session")
def k8s() -> client.CoreV1Api:
    k8s_config.load_kube_config()
    return client.CoreV1Api()


@pytest.fixture(scope="session")
def k8s_apps() -> client.AppsV1Api:
    k8s_config.load_kube_config()
    return client.AppsV1Api()
