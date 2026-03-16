# Contributing to kseed

Thank you for your interest in contributing to kseed! This document provides guidelines for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Commit Messages](#commit-messages)

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/). By participating, you are expected to uphold this code. Please report unacceptable behavior to the maintainers.

## Getting Started

1. **Fork the repository** - Click the "Fork" button on GitHub
2. **Clone your fork** - `git clone https://github.com/YOUR_USERNAME/kseed.git`
3. **Add upstream remote** - `git remote add upstream https://github.com/ORIGINAL_OWNER/kseed.git`
4. **Create a branch** - `git checkout -b feature/your-feature-name`

## Development Setup

### Prerequisites

- Python 3.14+
- Poetry (for dependency management)

### Installation

```bash
# Install dependencies
cd kseed
poetry install

# Activate virtual environment
poetry shell
```

### Running Tests

```bash
# Run all tests with coverage
poetry run pytest tests/ -v --cov=kseed --cov-report=term

# Run tests in watch mode
poetry run pytest tests/ -v --watch
```

### Running Linters

```bash
# Check code style
poetry run ruff check .

# Check code formatting
poetry run ruff format --check .

# Run security scan
poetry run bandit -r kseed/
```

## Making Changes

1. **Keep your fork in sync** - Regularly pull from upstream
   ```bash
   git fetch upstream
   git checkout main
   git merge upstream/main
   ```

2. **Create a feature branch** - Use descriptive branch names
   - `feature/add-new-command` - New features
   - `fix/bug-description` - Bug fixes
   - `docs/improvement` - Documentation updates

3. **Make incremental commits** - Small, focused commits are easier to review

4. **Write tests** - Ensure new code has appropriate test coverage

## Submitting Changes

### Pull Request Process

1. **Update documentation** - Any new functionality should be documented
2. **Run the full test suite** - Ensure all tests pass locally
3. **Run linters** - Fix any linting issues
   ```bash
   poetry run ruff check .
   poetry run ruff format --check .
   ```
4. **Push to your fork** - `git push origin your-branch-name`
5. **Open a Pull Request** - Fill out the PR template completely

### Pull Request Template

When opening a PR, please include:

- Clear description of the changes
- Related issue numbers (e.g., "Fixes #123")
- Testing performed
- Any breaking changes

## Coding Standards

### Python Style

This project uses [Ruff](https://docs.astral.sh/ruff/) for linting and formatting:

- Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/) style guide
- Use type hints where appropriate
- Maximum line length: 100 characters
- Target Python version: 3.14

### Code Quality

- Write clean, readable code with appropriate comments
- Use descriptive variable and function names
- Keep functions and methods focused (single responsibility)
- Remove debug code and unused imports before committing

### Docstrings

Use Google-style docstrings:

```python
def function(param1: str, param2: int) -> bool:
    """Short summary of function.

    Longer description if needed.

    Args:
        param1: Description of param1.
        param2: Description of param2.

    Returns:
        Description of return value.

    Raises:
        ValueError: Description of when this is raised.
    """
```

## Testing

### Test Organization

- Tests are located in `kseed/tests/`
- Test files should mirror the source structure: `tests/test_module.py` for `kseed/module.py`
- Use descriptive test names: `test_function_name_scenario`

### Writing Tests

```python
import pytest
from kseed.module import function_to_test

class TestFunctionToTest:
    """Tests for the function_to_test function."""

    def test_basic_case(self) -> None:
        """Test basic functionality."""
        result = function_to_test("input")
        assert result == "expected"

    def test_edge_case(self) -> None:
        """Test edge case handling."""
        with pytest.raises(ValueError):
            function_to_test("invalid")
```

### Test Coverage

- Aim for high test coverage on new code
- Minimum threshold: 80% coverage
- Run coverage report: `poetry run pytest --cov=kseed --cov-report=term`

## Commit Messages

This project follows the [Angular Commit Message Format](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit) as used by semantic-release.

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples

```
feat(cli): add new command for cluster diagnostics

Added 'diagnose' command to check cluster health and display
relevant metrics for troubleshooting.

Closes #123
```

```
fix(config): handle missing environment variables gracefully

Previously the application would crash if ENV_VAR was not set.
Now it falls back to defaults and logs a warning.
```

### Rules

- Use imperative mood: "add feature" not "added feature"
- First line should be under 72 characters
- Reference issues in footer: "Closes #123" or "Fixes #456"

## Recognition

Contributors will be recognized in the project documentation and release notes.

## Questions?

If you have questions, please open an issue or reach out to the maintainers.
