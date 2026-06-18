# Contributing

<!--date_added:thurs18jun2026-->
<!--date_updated:thurs18jun2026-->

This is a **public repository**

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

