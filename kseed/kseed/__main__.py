"""Main entry point for kseed CLI and Pulumi program."""

import sys

# CLI entry point
if len(sys.argv) > 1 and sys.argv[1] == "infra":
    # Run Pulumi infrastructure
    from kseed.infra import create_infrastructure
    import pulumi

    stack_name = pulumi.get_stack()
    create_infrastructure(stack_name)
else:
    # Run CLI
    from kseed import app

    app()
