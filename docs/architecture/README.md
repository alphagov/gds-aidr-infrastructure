# Architecture diagrams

<!--date_created: tues-07-july-2026-->
<!--date_updated: weds-08-july-2026-->

## What this folder is

Plain text diagrams describing how the AIDR platform fits together, using Mermaid — a free, open-source diagram syntax that GitHub renders automatically. No paid plan, no API key, no separate rendering step. Open any `.md` file in this folder on GitHub and the diagram displays as a picture directly on the page.

No need to open any special tool to understand the system. Each file explains itself in plain English first, then shows the diagram.

---

## System overview (`system-overview.md`)

The whole platform in one picture. Three separate AWS accounts — Development, Staging, and Production — each fully isolated from the others. People access the accounts through a central login system called `gds-users`, with a security code (MFA) required every time. Automated deployments use a separate, short-lived login method (OIDC) so no long-term passwords are stored anywhere. Production's automation is trusted to reach into Development and Staging when needed, but not the other way round.

## Networking (`networking.md`)

How each account's private network is laid out. Three zones:
- **Public** — only used for internet-facing pieces (currently just the NAT gateway)
- **Private App** — where the actual services run (containers, functions)
- **Private Data** — reserved for future databases, with no internet access at all

## Compute (`compute.md`)

How a running service gets its permissions. Two separate permission sets are always used: one for starting the container, one for the application's own work. Never combined.

## Data lake (`data-lake.md`)

Where synthetic data is stored. One encrypted storage location in Production, split into a "datasets" area and a "metadata" area, with every access logged.

## IAM (`iam.md`)

Who and what can access the platform. Six types of human role plus two types of workload role. All human access requires MFA; all automated access uses short-lived, repository-restricted tokens.

---

## Editing a diagram

Edit the Mermaid code block directly in the `.md` file, commit, push. GitHub re-renders it automatically — no build step, no external service, nothing to configure.

To preview locally before committing, either use the Mermaid Live Editor at https://mermaid.live (paste the code block in), or install the Mermaid extension in VS Code for an inline preview.