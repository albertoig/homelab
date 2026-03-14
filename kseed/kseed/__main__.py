"""Main entry point for kseed Pulumi program."""

from kseed.infra import create_infrastructure

if __name__ == "__main__":
    # Get stack name to determine environment
    import pulumi

    stack_name = pulumi.get_stack()
    create_infrastructure(stack_name)
