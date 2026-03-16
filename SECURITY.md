# Security Policy

## Supported Versions

The following versions of kseed are currently supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability within kseed, please send an email to the maintainers. All security vulnerabilities will be promptly addressed.

Please include the following information:

- Type of vulnerability
- Full paths of source file(s) related to the vulnerability
- Location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

## What to Expect

- **Acknowledgment**: You should receive a acknowledgment within 24 hours.
- **Timeline**: We aim to address critical vulnerabilities within 7 days.
- **Disclosure**: We will work with you to create a patch and coordinate disclosure.
- **Credit**: We will include your name in the security advisory (unless you prefer to remain anonymous).

## Security Best Practices

### Dependencies

- This project uses [Dependabot](https://docs.github.com/en/code-security/dependabot) to monitor dependencies for vulnerabilities
- Dependencies are reviewed in every pull request via our CI pipeline
- We use [Poetry](https://python-poetry.org/) for reproducible dependency management

### Code Scanning

The project uses automated security scanning:

- **Bandit**: Static security analysis for Python
- **Dependency Review**: Checks for known CVEs in dependencies
- **CodeQL**: GitHub's code analysis engine

### Secrets Management

- Never commit plaintext secrets to the repository
- Use environment variables for configuration when possible

## Security Updates

Security updates will be released as patch versions and announced in:

- The [GitHub Security Advisories](https://github.com/homelab/kseed/security/advisories) page
- The [Changelog](CHANGELOG.md)

## Thanks

Thank you for helping keep kseed and its users safe!
