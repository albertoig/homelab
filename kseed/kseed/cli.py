"""CLI for kseed Pulumi management."""

import os
import subprocess
from pathlib import Path

import typer
import yaml
from rich.console import Console
from rich.table import Table

from kseed import config as kseed_config
from kseed.config import HomelabConfig

app = typer.Typer(help="Megahomelab Pulumi CLI")
console = Console()


@app.command()
def init(
    environment: str = typer.Argument(..., help="Environment name (e.g., dev, prod)"),
    kubeconfig_path: str | None = typer.Option(
        None,
        "--kubeconfig",
        "-k",
        help="Path to kubeconfig file (default: ~/.kube/config)",
    ),
) -> None:
    """Initialize configuration for an environment."""
    console.print(f"[bold cyan]Initializing kseed for environment: {environment}[/bold cyan]\n")

    try:
        kubeconfig = Path(kubeconfig_path) if kubeconfig_path else None
        kseed_config.setup_kubeconfig(environment, kubeconfig)
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def configure(
    environment: str = typer.Argument(..., help="Environment name"),
) -> None:
    """Reconfigure kubeconfig for an existing environment."""
    console.print(f"[bold cyan]Reconfiguring kseed for environment: {environment}[/bold cyan]\n")

    # Delete existing config and re-run setup
    config = HomelabConfig(environment)
    config.load()

    if config.kubeconfig_path or config.kubeconfig_context:
        console.print("[yellow]Configuration exists. Removing...[/yellow]")

    kseed_config.setup_kubeconfig(environment)


@app.command()
def status(
    environment: str = typer.Argument(..., help="Environment name"),
) -> None:
    """Show configuration status for an environment."""
    config = HomelabConfig(environment)
    config.load()

    table = Table(title=f"Configuration for {environment}")
    table.add_column("Setting", style="cyan")
    table.add_column("Value", style="green")

    if config.kubeconfig_path:
        table.add_row("kubeconfig_path", str(config.kubeconfig_path))
    else:
        table.add_row("kubeconfig_path", "[red]Not configured[/red]")

    if config.kubeconfig_context:
        table.add_row("kubeconfig_context", config.kubeconfig_context)
    else:
        table.add_row("kubeconfig_context", "[red]Not configured[/red]")

    table.add_row("state_path", str(kseed_config.get_state_path(environment)))

    console.print(table)


@app.command()
def up(
    environment: str = typer.Argument(..., help="Environment name"),
    plan: bool = typer.Option(False, "--plan", "-p", help="Show plan only"),
) -> None:
    """Run pulumi up for the specified environment."""
    _run_pulumi(environment, "up", plan)


@app.command()
def preview(
    environment: str = typer.Argument(..., help="Environment name"),
) -> None:
    """Run pulumi preview for the specified environment."""
    _run_pulumi(environment, "preview", False)


@app.command()
def destroy(
    environment: str = typer.Argument(..., help="Environment name"),
    plan: bool = typer.Option(False, "--plan", "-p", help="Show plan only"),
) -> None:
    """Run pulumi destroy for the specified environment."""
    _run_pulumi(environment, "destroy", plan)


def _run_pulumi(environment: str, command: str, plan_only: bool) -> None:
    """Run a pulumi command with the correct configuration."""
    config = HomelabConfig(environment)
    config.load()

    # Check if configured
    if not config.kubeconfig_path or not config.kubeconfig_context:
        console.print(f"[red]Environment '{environment}' is not configured.[/red]")
        console.print(f"Run 'kseed init {environment}' first.")
        raise typer.Exit(1)

    # Get kubeconfig path and context
    kubeconfig_path = config.kubeconfig_path
    kubeconfig_context = config.kubeconfig_context

    # Read the kubeconfig and extract the selected context
    kubeconfig_content = _get_kubeconfig_for_context(kubeconfig_path, kubeconfig_context)

    # Get state path
    state_path = kseed_config.get_state_path(environment)
    state_path.parent.mkdir(parents=True, exist_ok=True)

    # Export kubeconfig to environment for pulumi
    env = os.environ.copy()
    env["KUBECONFIG"] = kubeconfig_content

    # Set pulumi to use file state
    env["PULUMI_BACKEND_URL"] = f"file://{state_path}"

    # Find project path (parent of kseed package)
    project_path = Path(__file__).parent.parent

    # Build pulumi command
    pulumi_cmd = ["pulumi", command, "--stack", environment]
    if plan_only:
        pulumi_cmd.append("--plan")

    console.print(f"[bold cyan]Running: {' '.join(pulumi_cmd)}[/bold cyan]")
    console.print(f"[dim]State: {state_path}[/dim]\n")

    try:
        result = subprocess.run(
            pulumi_cmd,
            cwd=project_path,
            env=env,
            text=True,
        )
        raise typer.Exit(result.returncode)
    except subprocess.CalledProcessError as e:
        console.print(f"[red]Error running pulumi: {e}[/red]")
        raise typer.Exit(1)


def _get_kubeconfig_for_context(kubeconfig_path: Path, context_name: str) -> str:
    """Extract kubeconfig content for a specific context."""
    with open(kubeconfig_path) as f:
        config = yaml.safe_load(f)

    # Find the context
    context = None
    for ctx in config.get("contexts", []):
        if ctx["name"] == context_name:
            context = ctx["context"]
            break

    if not context:
        raise ValueError(f"Context '{context_name}' not found in kubeconfig")

    # Get cluster info
    cluster_name = context.get("cluster")
    user_name = context.get("user")

    cluster_info = None
    for cluster in config.get("clusters", []):
        if cluster["name"] == cluster_name:
            cluster_info = cluster["cluster"]
            break

    user_info = None
    for user in config.get("users", []):
        if user["name"] == user_name:
            user_info = user.get("user", {})
            break

    # Build context-specific kubeconfig
    context_config = {
        "apiVersion": "v1",
        "kind": "Config",
        "contexts": [{"name": context_name, "context": context}],
        "current-context": context_name,
        "clusters": [{"name": cluster_name, "cluster": cluster_info}],
        "users": [{"name": user_name, "user": user_info}],
    }

    return yaml.safe_dump(context_config, default_flow_style=False)


def main() -> None:
    """Main entry point."""
    app()
