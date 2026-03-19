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

# Default project configuration
DEFAULT_PROJECT = {
    "name": "homelab",
    "description": "KSeed infrastructure",
    "runtime": "python",
    "main": "kseed/",
}


class KSeedConfig:
    """Manages kseed configuration stored in ~/.kseed/config."""

    def __init__(self, environment: str = "dev"):
        self.environment = environment
        self._config: dict[str, Any] = {}
        self._project_config: dict[str, Any] = {}
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
            # Get global project config
            self._project_config = all_config.get("project", {})
            # Get environment-specific config
            self._config = all_config.get(self.environment, {})

    def _save_config_file(self) -> None:
        """Save configuration to the single config file."""
        # Load existing config for other environments
        all_config = {}
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE) as f:
                all_config = yaml.safe_load(f) or {}

        # Update project config
        all_config["project"] = self._project_config
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

    @property
    def project_name(self) -> str:
        """Get the project name."""
        return self._project_config.get("name", DEFAULT_PROJECT["name"])

    @property
    def project_description(self) -> str:
        """Get the project description."""
        return self._project_config.get("description", DEFAULT_PROJECT["description"])

    @property
    def project_runtime(self) -> str:
        """Get the project runtime."""
        return self._project_config.get("runtime", DEFAULT_PROJECT["runtime"])

    @property
    def project_main(self) -> str:
        """Get the project main path."""
        return self._project_config.get("main", DEFAULT_PROJECT["main"])

    @property
    def components(self) -> list[dict[str, Any]]:
        """Get the components configuration."""
        return self._config.get("components", [])

    def set_project_config(self, name: str = None, description: str = None, runtime: str = None, main: str = None) -> None:
        """Set project configuration values."""
        if name is not None:
            self._project_config["name"] = name
        if description is not None:
            self._project_config["description"] = description
        if runtime is not None:
            self._project_config["runtime"] = runtime
        if main is not None:
            self._project_config["main"] = main
        self._save_config_file()

    def set_components(self, components: list[dict[str, Any]]) -> None:
        """Set the components configuration."""
        self._config["components"] = components
        self._save_config_file()

    @property
    def state_dir(self) -> Path | None:
        """Get the state directory from config."""
        return self._project_config.get("state_dir")

    @property
    def components_list(self) -> list[dict[str, Any]]:
        """Get the components list."""
        return self._config.get("components", [])


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

    # If kubeconfig_path is provided, don't prompt
    if kubeconfig_path is None:
        # Ask for kubeconfig path
        default_path = str(config.kubeconfig_path or DEFAULT_KUBECONFIG_PATH)
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


def setup_environment(environment: str) -> KSeedConfig:
    """Interactive setup for an environment, prompting for all config values.
    
    If config already exists, uses current values as defaults.
    If config doesn't exist, uses sensible defaults.
    """
    config = KSeedConfig(environment)
    config.load()

    console.print(f"[bold cyan]Setting up environment: {environment}[/bold cyan]\n")

    # Project settings
    console.print("[bold]Project Settings[/bold]")
    
    # Project name
    default_name = config.project_name
    project_name = Prompt.ask(
        "  [cyan]Project name[/cyan]",
        default=default_name,
    )
    
    # Project description
    default_desc = config.project_description
    project_desc = Prompt.ask(
        "  [cyan]Project description[/cyan]",
        default=default_desc,
    )
    
    # Runtime
    default_runtime = config.project_runtime
    runtime = Prompt.ask(
        "  [cyan]Runtime[/cyan]",
        default=default_runtime,
    )
    
    # Main path
    default_main = config.project_main
    main_path = Prompt.ask(
        "  [cyan]Main path[/cyan]",
        default=default_main,
    )
    
    # State directory
    default_state_dir = str(config.state_dir or KSEED_DIR / "statefiles")
    state_dir = Prompt.ask(
        "  [cyan]State directory[/cyan]",
        default=default_state_dir,
    )

    # Save project settings
    config._project_config = {
        "name": project_name,
        "description": project_desc,
        "runtime": runtime,
        "main": main_path,
        "state_dir": state_dir,
    }

    # Kubeconfig settings
    console.print("\n[bold]Kubernetes Settings[/bold]")
    
    # Kubeconfig path
    default_kube_path = str(config.kubeconfig_path or DEFAULT_KUBECONFIG_PATH)
    kube_path_str = Prompt.ask(
        "  [cyan]Kubeconfig path[/cyan]",
        default=default_kube_path,
    )
    kube_path = Path(kube_path_str)
    
    if not kube_path.exists():
        console.print(f"[yellow]Warning: Kubeconfig file not found: {kube_path}[/yellow]")
    else:
        # Select context
        console.print(f"\n[bold]Available contexts in {kube_path}:[/bold]")
        try:
            context = select_kubeconfig_context(kube_path)
        except ValueError:
            context = None
            console.print("[yellow]No contexts available[/yellow]")
    
    # Save environment config
    config._config = {
        "kubeconfig_path": str(kube_path) if kube_path.exists() else str(DEFAULT_KUBECONFIG_PATH),
        "kubeconfig_context": context or "",
    }
    
    config._save_config_file()

    console.print(f"\n[green]Configuration saved for environment: {environment}[/green]")
    console.print(f"  project: {project_name}")
    console.print(f"  kubeconfig: {config._config.get('kubeconfig_path')}")
    console.print(f"  context: {config._config.get('kubeconfig_context')}")

    return config
