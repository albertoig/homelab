"""Pulumi Automation API integration for KSeed.

This module provides programmatic access to Pulumi operations using the
Automation API, eliminating the need for a Pulumi.yaml file.
"""

import os
import shutil
from pathlib import Path
from typing import Any, Optional

import yaml
import pulumi.automation as auto
from rich.console import Console

console = Console()


def check_pulumi(verbose: bool = True) -> Optional[auto.PulumiCommand]:
    """Check if Pulumi CLI is installed and return a PulumiCommand if available.

    Args:
        verbose: If True, print status messages.

    Returns:
        PulumiCommand if pulumi is installed, None otherwise.
    """
    # Check if pulumi is in PATH
    pulumi_path = shutil.which("pulumi")
    if pulumi_path:
        try:
            # Verify it works and get version
            cmd = auto.PulumiCommand(skip_version_check=True)
            if verbose:
                console.print(f"[green]✓ Pulumi CLI found: {pulumi_path} (v{cmd.version})[/green]")
            return cmd
        except Exception as e:
            if verbose:
                console.print(
                    f"[yellow]⚠ Pulumi found at {pulumi_path} but failed to initialize: {e}[/yellow]"
                )

    # Also check in ~/.pulumi/versions/ for installed versions
    home = Path.home()
    pulumi_versions_dir = home / ".pulumi" / "versions"
    if pulumi_versions_dir.exists():
        # Find the latest version directory
        version_dirs = sorted(pulumi_versions_dir.iterdir(), reverse=True)
        for vdir in version_dirs:
            potential_pulumi = vdir / "bin" / "pulumi"
            if potential_pulumi.exists():
                try:
                    # Create a PulumiCommand with custom root
                    cmd = auto.PulumiCommand(root=str(vdir), skip_version_check=True)
                    if verbose:
                        console.print(
                            f"[green]✓ Pulumi CLI found: {potential_pulumi} (v{cmd.version})[/green]"
                        )
                    return cmd
                except Exception as e:
                    if verbose:
                        console.print(
                            f"[yellow]⚠ Pulumi found at {potential_pulumi} but failed: {e}[/yellow]"
                        )

    return None


def install_pulumi() -> auto.PulumiCommand:
    """Install Pulumi CLI and return the PulumiCommand.

    Returns:
        PulumiCommand for the installed pulumi CLI.

    Raises:
        Exception if installation fails.
    """
    console.print("[cyan]Installing Pulumi CLI...[/cyan]")

    try:
        cmd = auto.PulumiCommand.install(skip_version_check=True)
        console.print(f"[green]✓ Pulumi CLI installed: {cmd.command} (v{cmd.version})[/green]")
        return cmd
    except Exception as e:
        console.print(f"[red]✗ Failed to install Pulumi: {e}[/red]")
        raise


def ensure_pulumi() -> auto.PulumiCommand:
    """Ensure Pulumi CLI is available, installing if necessary.

    Returns:
        PulumiCommand for pulumi CLI.
    """
    cmd = check_pulumi()
    if cmd:
        return cmd

    console.print("[yellow]Pulumi CLI not found![/yellow]")
    console.print("Would you like kseed to install Pulumi? (y/n)")

    # For non-interactive use, we'll install automatically
    # In interactive mode, you'd want to prompt the user
    return install_pulumi()


# Default KSeed configuration
KSEED_DIR = Path.home() / ".kseed"
CONFIG_FILE = KSEED_DIR / "config"
DEFAULT_STATE_DIR = KSEED_DIR / "statefiles"


class PulumiConfig:
    """Pulumi project configuration loaded from .kseed/config."""

    def __init__(self, environment: str = "dev"):
        self.environment = environment
        self._config: dict[str, Any] = {}
        self._load_config()

    def _load_config(self) -> None:
        """Load configuration from .kseed/config."""
        if not CONFIG_FILE.exists():
            return

        with open(CONFIG_FILE) as f:
            all_config = yaml.safe_load(f) or {}

        self._config = all_config.get(self.environment, {})

    @property
    def project_name(self) -> str:
        """Get the Pulumi project name."""
        return self._config.get("project", {}).get("name", "homelab")

    @property
    def project_description(self) -> str:
        """Get the Pulumi project description."""
        return self._config.get("project", {}).get("description", "KSeed infrastructure")

    @property
    def runtime(self) -> str:
        """Get the Pulumi runtime."""
        return self._config.get("project", {}).get("runtime", "python")

    @property
    def main_path(self) -> str:
        """Get the main entry point path."""
        return self._config.get("project", {}).get("main", "kseed/")

    @property
    def state_dir(self) -> Path:
        """Get the state directory."""
        state_path = self._config.get("project", {}).get("state_dir")
        if state_path:
            return Path(state_path)
        DEFAULT_STATE_DIR.mkdir(parents=True, exist_ok=True)
        return DEFAULT_STATE_DIR

    @property
    def backend_url(self) -> str:
        """Get the Pulumi backend URL."""
        # Use local file backend
        return f"file://{self.state_dir}"

    @property
    def kubeconfig_path(self) -> Optional[Path]:
        """Get the kubeconfig path."""
        path = self._config.get("kubeconfig_path")
        return Path(path) if path else None

    @property
    def kubeconfig_context(self) -> Optional[str]:
        """Get the kubeconfig context."""
        return self._config.get("kubeconfig_context")

    @property
    def components(self) -> list[dict[str, Any]]:
        """Get the components configuration."""
        return self._config.get("components", [])


def create_stack(
    environment: str,
    program: Any,
    stack_name: Optional[str] = None,
) -> auto.Stack:
    """Create or select a Pulumi stack.

    Args:
        environment: The environment name (e.g., 'dev', 'prod')
        program: The Pulumi program function
        stack_name: Optional stack name (defaults to environment)

    Returns:
        The Pulumi stack
    """
    config = PulumiConfig(environment)

    if stack_name is None:
        stack_name = environment

    # Ensure pulumi is installed
    pulumi_cmd = ensure_pulumi()

    # Create stack with automation API
    stack = auto.create_stack(
        stack_name=stack_name,
        project_name=config.project_name,
        program=program,
        opts=auto.LocalWorkspaceOptions(
            work_dir=str(config.state_dir),
            secrets_provider="default",
            pulumi_command=pulumi_cmd,
        ),
    )

    # Set the backend URL
    stack.workspace.backend_url = config.backend_url

    return stack


def run_up(
    environment: str,
    program: Any,
    stack_name: Optional[str] = None,
    preview_only: bool = False,
) -> auto.UpResult:
    """Run pulumi up for the specified environment.

    Args:
        environment: The environment name
        program: The Pulumi program function
        stack_name: Optional stack name
        preview_only: If True, only run preview

    Returns:
        The Pulumi up result
    """
    config = PulumiConfig(environment)

    if stack_name is None:
        stack_name = environment

    # Get kubeconfig content
    kubeconfig_content = _get_kubeconfig_content(config)

    # Set environment variables
    env = os.environ.copy()
    if kubeconfig_content:
        env["KUBECONFIG"] = kubeconfig_content

    # For local development without passphrase, set a default empty passphrase
    if "PULUMI_CONFIG_PASSPHRASE" not in env and "PULUMI_CONFIG_PASSPHRASE_FILE" not in env:
        env["PULUMI_CONFIG_PASSPHRASE"] = ""

    # Ensure pulumi is installed
    pulumi_cmd = ensure_pulumi()

    # Create stack
    try:
        stack = auto.create_stack(
            stack_name=stack_name,
            project_name=config.project_name,
            program=program,
            opts=auto.LocalWorkspaceOptions(
                work_dir=str(config.state_dir),
                env_vars=env,
                secrets_provider="default",
                pulumi_command=pulumi_cmd,
            ),
        )
    except auto.StackAlreadyExistsError:
        stack = auto.select_stack(
            stack_name=stack_name,
            project_name=config.project_name,
            program=program,
            opts=auto.LocalWorkspaceOptions(
                work_dir=str(config.state_dir),
                env_vars=env,
                secrets_provider="default",
                pulumi_command=pulumi_cmd,
            ),
        )

    # Refresh before up
    stack.refresh(on_output=console.print)

    if preview_only:
        console.print(f"[bold cyan]Running preview for {environment}[/bold cyan]")
        result = stack.preview(on_output=console.print)
    else:
        console.print(f"[bold cyan]Running up for {environment}[/bold cyan]")
        result = stack.up(on_output=console.print)

    return result


def run_preview(
    environment: str,
    program: Any,
    stack_name: Optional[str] = None,
) -> auto.PreviewResult:
    """Run pulumi preview for the specified environment.

    Args:
        environment: The environment name
        program: The Pulumi program function
        stack_name: Optional stack name

    Returns:
        The Pulumi preview result
    """
    config = PulumiConfig(environment)

    if stack_name is None:
        stack_name = environment

    # Get kubeconfig content
    kubeconfig_content = _get_kubeconfig_content(config)

    # Set environment variables
    env = os.environ.copy()
    if kubeconfig_content:
        env["KUBECONFIG"] = kubeconfig_content

    # For local development without passphrase, set a default empty passphrase
    if "PULUMI_CONFIG_PASSPHRASE" not in env and "PULUMI_CONFIG_PASSPHRASE_FILE" not in env:
        env["PULUMI_CONFIG_PASSPHRASE"] = ""

    # Ensure pulumi is installed
    pulumi_cmd = ensure_pulumi()

    try:
        stack = auto.create_stack(
            stack_name=stack_name,
            project_name=config.project_name,
            program=program,
            opts=auto.LocalWorkspaceOptions(
                work_dir=str(config.state_dir),
                env_vars=env,
                secrets_provider="default",
                pulumi_command=pulumi_cmd,
            ),
        )
    except auto.StackAlreadyExistsError:
        stack = auto.select_stack(
            stack_name=stack_name,
            project_name=config.project_name,
            program=program,
            opts=auto.LocalWorkspaceOptions(
                work_dir=str(config.state_dir),
                env_vars=env,
                secrets_provider="default",
                pulumi_command=pulumi_cmd,
            ),
        )

    console.print(f"[bold cyan]Running preview for {environment}[/bold cyan]")
    result = stack.preview(on_output=console.print)

    return result


def run_destroy(
    environment: str,
    program: Any,
    stack_name: Optional[str] = None,
) -> auto.DestroyResult:
    """Run pulumi destroy for the specified environment.

    Args:
        environment: The environment name
        program: The Pulumi program function
        stack_name: Optional stack name

    Returns:
        The Pulumi destroy result
    """
    config = PulumiConfig(environment)

    if stack_name is None:
        stack_name = environment

    # Get kubeconfig content
    kubeconfig_content = _get_kubeconfig_content(config)

    # Set environment variables
    env = os.environ.copy()
    if kubeconfig_content:
        env["KUBECONFIG"] = kubeconfig_content

    # For local development without passphrase, set a default empty passphrase
    if "PULUMI_CONFIG_PASSPHRASE" not in env and "PULUMI_CONFIG_PASSPHRASE_FILE" not in env:
        env["PULUMI_CONFIG_PASSPHRASE"] = ""

    # Ensure pulumi is installed
    pulumi_cmd = ensure_pulumi()

    try:
        stack = auto.select_stack(
            stack_name=stack_name,
            project_name=config.project_name,
            program=program,
            opts=auto.LocalWorkspaceOptions(
                work_dir=str(config.state_dir),
                env_vars=env,
                secrets_provider="default",
                pulumi_command=pulumi_cmd,
            ),
        )
    except auto.StackNotFoundError:
        console.print(f"[yellow]Stack {stack_name} not found, nothing to destroy[/yellow]")
        return None

    console.print(f"[bold cyan]Running destroy for {environment}[/bold cyan]")
    result = stack.destroy(on_output=console.print)

    return result


def _get_kubeconfig_content(config: PulumiConfig) -> Optional[str]:
    """Get kubeconfig content from the config.

    Args:
        config: The PulumiConfig instance

    Returns:
        The kubeconfig content or None
    """
    import yaml as pyyaml

    kubeconfig_path = config.kubeconfig_path
    kubeconfig_context = config.kubeconfig_context

    if not kubeconfig_path or not kubeconfig_context:
        return None

    if not kubeconfig_path.exists():
        console.print(f"[yellow]Kubeconfig file not found: {kubeconfig_path}[/yellow]")
        return None

    with open(kubeconfig_path) as f:
        full_config = pyyaml.safe_load(f)

    # Find the context
    context_info = None
    for ctx in full_config.get("contexts", []):
        if ctx.get("name") == kubeconfig_context:
            context_info = ctx.get("context", {})
            break

    if not context_info:
        console.print(f"[red]Context '{kubeconfig_context}' not found in kubeconfig[/red]")
        return None

    # Get cluster and user info
    cluster_name = context_info.get("cluster")
    user_name = context_info.get("user")

    cluster_info = None
    for cluster in full_config.get("clusters", []):
        if cluster.get("name") == cluster_name:
            cluster_info = cluster.get("cluster", {})
            break

    user_info = None
    for user in full_config.get("users", []):
        if user.get("name") == user_name:
            user_info = user.get("user", {})
            break

    # Build context-specific kubeconfig
    context_config = {
        "apiVersion": "v1",
        "kind": "Config",
        "contexts": [{"name": kubeconfig_context, "context": context_info}],
        "current-context": kubeconfig_context,
        "clusters": [{"name": cluster_name, "cluster": cluster_info}],
        "users": [{"name": user_name, "user": user_info}],
    }

    return pyyaml.dump(context_config)
