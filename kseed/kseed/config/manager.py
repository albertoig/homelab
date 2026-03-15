"""Configuration management for kseed Pulumi."""

from pathlib import Path
from typing import Any

import yaml
from rich.console import Console
from rich.prompt import Prompt

console = Console()

# Default paths
KSEED_DIR = Path.home() / ".kseed"
CONFIG_FILE = KSEED_DIR / "config"
STATE_DIR = KSEED_DIR / "statefiles"
DEFAULT_KUBECONFIG_PATH = Path.home() / ".kube" / "config"


class KSeedConfig:
    """Manages kseed configuration stored in ~/.kseed/config."""

    def __init__(self, environment: str = "dev"):
        self.environment = environment
        self._config: dict[str, Any] = {}
        self._ensure_config_dir()
        self._load_config_file()

    def _ensure_config_dir(self) -> None:
        """Ensure the config directory exists."""
        KSEED_DIR.mkdir(parents=True, exist_ok=True)

    def _load_config_file(self) -> None:
        """Load configuration from the single config file."""
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE) as f:
                all_config = yaml.safe_load(f) or {}
            # Get environment-specific config
            self._config = all_config.get(self.environment, {})

    def _save_config_file(self) -> None:
        """Save configuration to the single config file."""
        # Load existing config for other environments
        all_config = {}
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE) as f:
                all_config = yaml.safe_load(f) or {}

        # Update this environment's config
        all_config[self.environment] = self._config

        with open(CONFIG_FILE, "w") as f:
            yaml.safe_dump(all_config, f, default_flow_style=False)

    def load(self) -> dict[str, Any]:
        """Load configuration for this environment."""
        return self._config

    def save(self, config: dict[str, Any]) -> None:
        """Save configuration for this environment."""
        self._config = config
        self._save_config_file()

    def get(self, key: str, default: Any = None) -> Any:
        """Get a configuration value."""
        return self._config.get(key, default)

    def set(self, key: str, value: Any) -> None:
        """Set a configuration value."""
        self._config[key] = value
        self._save_config_file()

    @property
    def kubeconfig_path(self) -> Path | None:
        """Get the kubeconfig path from config."""
        path = self._config.get("kubeconfig_path")
        return Path(path) if path else None

    @property
    def kubeconfig_context(self) -> str | None:
        """Get the selected kubeconfig context from config."""
        return self._config.get("kubeconfig_context")


def get_state_path(environment: str) -> Path:
    """Get the Pulumi state path for the given environment."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    return STATE_DIR / f"{environment}.state"


def read_kubeconfig(kubeconfig_path: Path) -> dict[str, Any]:
    """Read and parse a kubeconfig file."""
    with open(kubeconfig_path) as f:
        return yaml.safe_load(f)


def get_available_contexts(kubeconfig_path: Path) -> list[str]:
    """Get all available contexts from a kubeconfig file."""
    config = read_kubeconfig(kubeconfig_path)
    contexts = config.get("contexts", [])
    return [ctx["name"] for ctx in contexts]


def select_kubeconfig_context(kubeconfig_path: Path) -> str:
    """Interactive context selector using Rich."""
    contexts = get_available_contexts(kubeconfig_path)

    if not contexts:
        console.print("[red]No contexts found in kubeconfig![/red]")
        raise ValueError("No contexts found in kubeconfig")

    if len(contexts) == 1:
        console.print(f"[green]Only one context found: {contexts[0]}[/green]")
        return contexts[0]

    console.print("\n[bold]Available contexts:[/bold]")
    for i, ctx in enumerate(contexts, 1):
        console.print(f"  {i}. {ctx}")

    choice = Prompt.ask(
        "\n[bold cyan]Select a context[/bold cyan]",
        choices=[str(i) for i in range(1, len(contexts) + 1)],
        default="1",
    )

    return contexts[int(choice) - 1]


def setup_kubeconfig(environment: str, kubeconfig_path: Path | None = None) -> KSeedConfig:
    """Interactive kubeconfig setup for an environment."""
    config = KSeedConfig(environment)
    config.load()

    # Check if already configured
    if config.kubeconfig_path and config.kubeconfig_context:
        console.print(f"[green]Already configured for {environment}[/green]")
        console.print(f"  kubeconfig: {config.kubeconfig_path}")
        console.print(f"  context: {config.kubeconfig_context}")
        return config

    # Ask for kubeconfig path
    if kubeconfig_path is None:
        default_path = str(DEFAULT_KUBECONFIG_PATH)
        kubeconfig_path_str = Prompt.ask(
            "[bold cyan]Kubeconfig path[/bold cyan]",
            default=default_path,
        )
        kubeconfig_path = Path(kubeconfig_path_str)

    if not kubeconfig_path.exists():
        console.print(f"[red]Kubeconfig file not found: {kubeconfig_path}[/red]")
        raise FileNotFoundError(f"Kubeconfig file not found: {kubeconfig_path}")

    # Select context
    console.print(f"\n[bold]Reading kubeconfig from: {kubeconfig_path}[/bold]")
    context = select_kubeconfig_context(kubeconfig_path)

    # Save configuration (stores path and context only)
    config.save(
        {
            "kubeconfig_path": str(kubeconfig_path),
            "kubeconfig_context": context,
        }
    )

    console.print(f"\n[green]Configuration saved for environment: {environment}[/green]")
    console.print(f"  kubeconfig: {kubeconfig_path}")
    console.print(f"  context: {context}")

    return config
