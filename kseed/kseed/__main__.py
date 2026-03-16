"""Main entry point for kseed CLI and Pulumi program."""

import sys

# CLI entry point
if len(sys.argv) > 1 and sys.argv[1] == "infra":
    # Run Pulumi infrastructure using Automation API
    from kseed.infra.automation import run_up
    from kseed.infra.resources import create_infrastructure

    environment = sys.argv[2] if len(sys.argv) > 2 else "dev"
    run_up(environment, create_infrastructure)
else:
    # Run CLI
    from kseed import app

    app()
