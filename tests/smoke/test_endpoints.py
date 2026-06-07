import pytest
import requests


def assert_reachable(http: requests.Session, url: str, expected_status: int = 200) -> None:
    try:
        response = http.get(url, timeout=10, allow_redirects=True)
    except requests.exceptions.ConnectionError as e:
        pytest.skip(f"Environment not reachable: {url} ({e})")
    except requests.exceptions.Timeout:
        pytest.fail(f"Timeout — service reachable but not responding: {url}")

    assert response.status_code == expected_status, (
        f"{url} returned {response.status_code}, expected {expected_status}"
    )


class TestAuthentik:
    def test_ui_reachable(self, http, urls):
        assert_reachable(http, urls["authentik"])

    def test_health(self, http, urls):
        assert_reachable(http, f"{urls['authentik']}/-/health/live/")

    def test_readiness(self, http, urls):
        assert_reachable(http, f"{urls['authentik']}/-/health/ready/")


class TestGrafana:
    def test_ui_reachable(self, http, urls):
        # Grafana redirects unauthenticated users to login (302 → 200)
        assert_reachable(http, urls["grafana"])

    def test_health(self, http, urls):
        assert_reachable(http, f"{urls['grafana']}/api/health")


class TestArgoCD:
    def test_ui_reachable(self, http, urls):
        assert_reachable(http, urls["argocd"])

    def test_health(self, http, urls):
        assert_reachable(http, f"{urls['argocd']}/healthz")


class TestLonghorn:
    def test_ui_reachable(self, http, urls):
        assert_reachable(http, urls["longhorn"])
