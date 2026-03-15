# Kseed Repository Analysis & Recommendations

## Current Structure Overview

```
kseed/
├── kseed/              # Main package
│   ├── __init__.py     # Package init + version
│   ├── __main__.py     # CLI entry point
│   ├── cli.py          # CLI commands (init, configure, status, up, destroy)
│   ├── config.py       # Configuration management
│   └── infra.py        # Pulumi infrastructure code
├── tests/              # Unit tests (31 tests)
├── pyproject.toml      # Poetry + PSR config
├── Pulumi.yaml         # Pulumi project config
└── README.md           # Documentation
```

---

## 1. Code Structure Improvements

### 1.1 Add Type Hints to infra.py
**Current:** Limited type hints
**Recommended:** Add complete type annotations for better IDE support and documentation

### 1.2 Separate CLI from Business Logic
**Current:** CLI commands directly call config functions
**Recommended:** Create a cleaner separation with a `kseed/` package structure:
```
kseed/
├── __init__.py
├── __main__.py
├── cli/
│   ├── __init__.py
│   └── commands.py     # CLI commands only
├── core/
│   ├── __init__.py
│   ├── config.py       # Config management
│   └── kubernetes.py   # K8s utilities
└── infra/
    ├── __init__.py
    └── resources.py    # Pulumi resources
```

### 1.3 Add __all__ Exports
**Recommended:** Explicit exports in `__init__.py`:
```python
__all__ = ["KSeedConfig", "app", "main"]
```

---

## 2. CI/CD Pipeline Recommendations

### 2.1 Current State (.github/workflows/release.yml)
- Uses PSR for versioning ✓
- Python 3.14 with Poetry ✓
- Triggers on main/master push ✓

### 2.2 Recommended CI/CD Additions

#### A) Linting Workflow (.github/workflows/lint.yml)
```yaml
name: Lint

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.14'
      - uses: snok/install-poetry@v1
      - run: poetry install
      - run: poetry run ruff check .
      - run: poetry run ruff format --check .
```

#### B) Testing Workflow (.github/workflows/test.yml)
```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.14'
      - uses: snok/install-poetry@v1
      - run: poetry install
      - run: poetry run pytest tests/ -v --cov=kseed --cov-report=xml
      - uses: codecov/codecov-action@v4
```

#### C) Pre-commit Hooks
Add `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.4
    hooks:
      - id: ruff
      - id: ruff-format
```

---

## 3. Testing Recommendations

### 3.1 Current Coverage
- ✅ 21 tests for config.py
- ✅ 10 tests for CLI commands
- ⚠️ No tests for infra.py

### 3.2 Add Tests for infra.py
```python
# tests/test_infra.py
class TestInfra:
    def test_get_config_value_from_env(self): ...
    def test_get_config_value_fallback(self): ...
    def test_create_namespace(self): ...
    def test_install_nginx_ingress(self): ...
```

### 3.3 Add Test Coverage
Install coverage plugin:
```bash
poetry add --group dev coverage
```

---

## 4. Documentation Improvements

### 4.1 API Documentation
Add docstrings following Google style:
```python
def create_namespace(name: str, provider: k8s.Provider) -> k8s.core.v1.Namespace:
    """Create a Kubernetes namespace.

    Args:
        name: The name of the namespace to create.
        provider: The Kubernetes provider to use.

    Returns:
        The created Namespace resource.

    Example:
        >>> provider = create_kubernetes_provider(kubeconfig)
        >>> ns = create_namespace("my-app", provider)
    """
```

### 4.2 Add mkdocs for Documentation Site
```bash
poetry add --group dev mkdocs mkdocs-material
```

---

## 5. Security Improvements

### 5.1 Add Dependabot Configuration
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/kseed"
    schedule:
      interval: "weekly"
```

### 5.2 Add Security Scanning
```yaml
# .github/workflows/security.yml
- uses: snyk/actions/setup@master
- run: snyk test --file=kseed/pyproject.toml
```

---

## 6. GitHub Actions Summary

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `release.yml` | Push to main | Version & release |
| `lint.yml` | Push/PR | Code quality |
| `test.yml` | Push/PR | Unit tests + coverage |
| `security.yml` | Weekly | Vulnerability scan |

---

## Priority Recommendations

1. **High Priority:**
   - Add lint workflow (ruff)
   - Add test workflow with coverage
   - Add tests for infra.py

2. **Medium Priority:**
   - Add pre-commit hooks
   - Add type hints to infra.py
   - Add security scanning

3. **Low Priority:**
   - Restructure package layout
   - Add mkdocs documentation
   - Add dependabot
