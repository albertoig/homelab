"""CLI commands for kseed Pulumi management."""

from pathlib import Path

import typer
import yaml
from rich.console import Console
from rich.table import Table

from kseed import config as kseed_config  # noqa: F401  # Used by tests for mocking
from kseed.config import KSeedConfig, setup_environment
from kseed.diagnose import ClusterHealth, check_cluster_health, get_all_configured_environments
from kseed.infra.automation import run_up, run_preview, run_destroy
from kseed.infra.resources import create_infrastructure

app = typer.Typer(help="Kseed CLI")
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
        setup_environment(environment)
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def configure(
    environment: str = typer.Argument(..., help="Environment name"),
) -> None:
    """Reconfigure kubeconfig for an existing environment."""
    console.print(f"[bold cyan]Reconfiguring kseed for environment: {environment}[/bold cyan]\n")

    try:
        setup_environment(environment)
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def status(
    environment: str = typer.Argument(..., help="Environment name"),
) -> None:
    """Show configuration status for an environment."""
    config = KSeedConfig(environment)
    config.load()

    table = Table(title=f"Configuration for {environment}")
    table.add_column("Setting", style="cyan")
    table.add_column("Value", style="green")

    # Project settings
    table.add_row("[bold]Project Settings[/bold]", "")
    table.add_row("  project_name", config.project_name)
    table.add_row("  project_runtime", config.project_runtime)
    table.add_row("  project_main", config.project_main)

    # Kubeconfig
    if config.kubeconfig_path:
        table.add_row("kubeconfig_path", str(config.kubeconfig_path))
    else:
        table.add_row("kubeconfig_path", "[red]Not configured[/red]")

    if config.kubeconfig_context:
        table.add_row("kubeconfig_context", config.kubeconfig_context)
    else:
        table.add_row("kubeconfig_context", "[red]Not configured[/red]")

    # Components
    components = config.components
    if components:
        table.add_row("[bold]Components[/bold]", "")
        for comp in components:
            table.add_row(f"  - {comp.get('name', 'unknown')}", str(comp.get('config', {})))
    else:
        table.add_row("components", "[yellow]No components configured[/yellow]")

    console.print(table)


@app.command()
def diagnose(
    environment: str | None = typer.Argument(
        None,
        help="Environment name (if not provided, tests all configured environments)",
    ),
) -> None:
    """Diagnose the connection to K3s cluster.

    Checks:
    - If the K3s cluster is reachable
    - If the user has permissions to access
    - If the user can install Helm charts
    """
    if environment:
        _test_single_environment(environment)
    else:
        _test_all_environments()


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
    """Run a pulumi command with the correct configuration using Automation API."""
    config = KSeedConfig(environment)
    config.load()

    # Check if configured
    if not config.kubeconfig_path or not config.kubeconfig_context:
        console.print(f"[red]Environment '{environment}' is not configured.[/red]")
        console.print(f"Run 'kseed init {environment}' first.")
        raise typer.Exit(1)

    console.print(f"[bold cyan]Running pulumi {command} for environment: {environment}[/bold cyan]\n")

    try:
        if command == "up":
            run_up(environment, create_infrastructure, preview_only=plan_only)
        elif command == "preview":
            run_preview(environment, create_infrastructure)
        elif command == "destroy":
            run_destroy(environment, create_infrastructure)
        else:
            console.print(f"[red]Unknown command: {command}[/red]")
            raise typer.Exit(1)
    except Exception as e:
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


def _test_single_environment(environment: str) -> None:
    """Test a single environment's cluster connectivity."""
    config = KSeedConfig(environment)
    config.load()

    if not config.kubeconfig_path or not config.kubeconfig_context:
        console.print(f"[red]Environment '{environment}' is not configured.[/red]")
        console.print(f"Run 'kseed init {environment}' first.")
        raise typer.Exit(1)

    console.print(f"[bold cyan]Testing cluster for environment: {environment}[/bold cyan]\n")

    try:
        health = check_cluster_health(
            environment=environment,
            kubeconfig_path=config.kubeconfig_path,
            context_name=config.kubeconfig_context,
        )
        _display_health_result(health)
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise typer.Exit(1)


def _test_all_environments() -> None:
    """Test all configured environments."""
    environments = get_all_configured_environments()

    if not environments:
        console.print("[yellow]No configured environments found.[/yellow]")
        console.print("Run 'kseed init <env>' first to configure an environment.")
        return

    console.print(f"[bold cyan]Testing {len(environments)} configured environment(s)[/bold cyan]\n")

    all_healthy = True
    for env in environments:
        config = KSeedConfig(env)
        config.load()

        if not config.kubeconfig_path or not config.kubeconfig_context:
            console.print(f"[yellow]Skipping {env} - not configured[/yellow]")
            continue

        try:
            health = check_cluster_health(
                environment=env,
                kubeconfig_path=config.kubeconfig_path,
                context_name=config.kubeconfig_context,
            )
            _display_health_result(health)
            console.print()

            if not (health.cluster_reachable and health.has_permissions):
                all_healthy = False
        except Exception as e:
            console.print(f"[red]Error testing {env}: {e}[/red]")
            all_healthy = False
            console.print()

    if all_healthy and environments:
        console.print("[bold green]✓ All environments are healthy![/bold green]")
    elif environments:
        console.print("[bold red]✗ Some environments have issues[/bold red]")


def _display_health_result(health: ClusterHealth) -> None:
    """Display health check result in a nice table."""
    table = Table(title=f"Health Check: {health.environment}")
    table.add_column("Check", style="cyan")
    table.add_column("Status", style="green")

    # Cluster reachable
    if health.cluster_reachable:
        status = "[green]✓ Reachable[/green]"
        if health.cluster_info:
            status += f"\n   {health.cluster_info}"
    else:
        status = "[red]✗ Unreachable[/red]"
    table.add_row("Cluster Reachable", status)

    # Has permissions
    if health.has_permissions:
        table.add_row("Permissions", "[green]✓ Access granted[/green]")
    else:
        table.add_row("Permissions", "[red]✗ Denied[/red]")

    # Can install Helm
    if health.can_install_helm:
        table.add_row("Helm Install", "[green]✓ Allowed[/green]")
    else:
        table.add_row("Helm Install", "[red]✗ Restricted[/red]")

    # Error message
    if health.error_message:
        table.add_row("Error", f"[red]{health.error_message}[/red]")

    console.print(table)
