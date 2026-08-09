# Contributing

<!--date_added:thurs18jun2026-->
<!--date_updated:sun09aug2026-->

This is a **public repository**

# Contributing to gds-aidr-infrastructure

## Local setup

### Install pre-commit hooks

The repo uses `pre-commit` to run local checks before every commit — including secrets scanning, Terraform formatting, and basic hygiene.

Install `pre-commit` if you don't have it:

```bash
brew install pre-commit
```

Then install the hooks in this repo:

```bash
pre-commit install
```

Hooks now run automatically on every `git commit`. To run them manually against all files:

```bash
pre-commit run --all-files
```

### Install gitleaks (optional but recommended)

The pre-commit hook downloads `gitleaks` automatically, but you can also install it standalone to scan on demand:

```bash
brew install gitleaks
gitleaks detect --source . --config .gitleaks.toml
```

## What's checked

- **Secrets and account IDs** — via `gitleaks`. See `.gitleaks.toml` for the rules
- **Trailing whitespace, EOL, merge conflict markers** — basic file hygiene
- **YAML syntax** — catches malformed workflow files early
- **Terraform formatting** — `terraform fmt` on all `.tf` files
- **Large files** — files over 1MB are flagged

## Bypassing a hook

Occasionally a hook flags something that's genuinely fine. To skip all hooks for a single commit:

```bash
git commit --no-verify
```

To add a permanent exception, edit `.gitleaks.toml` (for secrets) or `.pre-commit-config.yaml` (for other hooks). Document why in the commit message.

## CI checks

The same `gitleaks` scan runs on every PR via `.github/workflows/secrets-scan.yml`. It blocks merge if it finds anything the local hook missed.

> **Note to developers:** 
> 1. Commit messages follow either the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/#specification) or [Angular Commit](https://github.com/angular/angular/blob/main/contributing-docs/commit-message-guidelines.md) specification. Use one commit per logical change — a commit can include multiple file edits, but they must all relate to the same underlying change.
> 2. All branches must follow the same pattern as commit messages, ie `topic(sub-topic): < your-commit-msg-here >`
> 3. We use [Semantic Versioning](https://semver.org/) for releases
> 4. All changes must be submitted by PR. No direct merges to main

## Linting and Version Control

To maintain code quality and consistency, this repository uses:

- **`terraform fmt`** and **`tflint`** for HCL/Terraform code
- **`eslint`** and **`prettier`** for JavaScript code

Before submitting a pull request, please ensure your code passes the linters by running the following from the repository root:

```bash
# Terraform — format check and lint
terraform fmt -check -recursive infrastructure/terraform
tflint --recursive --chdir infrastructure/terraform

# JavaScript — lint and format check
npx eslint .
npx prettier --check .
```

To auto-fix formatting issues locally before committing:

```bash
terraform fmt -recursive infrastructure/terraform
npx prettier --write .
```

These checks also run automatically on every push and pull request via the `Lint` GitHub Actions workflow (`.github/workflows/lint.yml`).

### Version Control

This repository follows the [GitHub Flow](https://guides.github.com/introduction/flow/) for version control:

1. Create a branch from `main` for your changes
2. Make your changes and commit them to your branch
3. Open a pull request to merge your changes into `main`
4. After review and approval, your changes will be merged

Please use descriptive commit messages and include a reference to any related issues or pull requests.

---

