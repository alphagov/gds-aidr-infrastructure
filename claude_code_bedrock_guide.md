# Connecting Claude Code to Amazon Bedrock on the AIDR Platform

<!--date_created:sun-14-jun-2026-->
<!--date_updated:weds-17-jun-2026-->

--- 

**Description:** This guide exists to help AIDR team members (data scientists, developers, analysts) and platform admins to connect Claude Code to Bedrock

# Contents

1. [What this is](#1-what-this-is)
2. [Prerequisites](#2-prerequisites)
3. [Bedrock Access](#3-bedrock-access)
4. [User setup](#4-user-setup)
5. [Verifying it works](#5-verifying-it-works)
6. [Troubleshooting](#6-troubleshooting)
7. [Cost and usage notes](#7-cost-and-usage-notes)
8. [Reference](#8-reference)

**Note:** Items marked *under review* have not been verified; they may not be required. 

## 1. What this is

**[Claude Code](https://code.claude.com/docs/en/overview)** is Anthropic's command-line coding assistant. It can be configured to route requests through Amazon Bedrock instead of Anthropic's own API. This means:

- **No Anthropic API key or subscription needed** — authentication uses your existing AWS credentials
- **Billing goes through the AIDR AWS account** — consolidated billing, tracked via cost allocation tags
- **Data stays within AWS** — using the EU cross-region inference profile keeps requests within EU regions
- **Access control uses existing IAM roles** — same roles you already use for the AIDR platform

Claude Code supports both the terminal CLI and the VS Code extension.

## 2. Prerequisites

### For everyone

- A `gds-users` account with an MFA serial configured (same as for any AIDR platform access)
- An AIDR role you can assume (e.g. `gds-aidr-data-scientist` in the Development account)
- AWS CLI installed and configured locally, ie a relevant profile for accessing the role you have been assigned to via `~.aws/config` and `~.aws/credentials`. 
- *under review* Node.js 18+ installed (Claude Code requires it)

### For platform admins only

- Admin or terraform role access to the Development account

> This guide assumes you are able to self-serve in accessing and setting up the prerequisites. If you have difficulty with any of these things, please reach out to a team member to ask directly for support. 

## 3. Bedrock access

> **Region note:** 
> The GDS-AIDR team implements region lock on **all global regions except `eu-west-2`. 
> *under review* Claude Sonnet 4.6 availability is exists in the in `eu-west-1` (Ireland) in-region. 
> For `eu-west-2` (London), you need to use the EU cross-region inference profile (`eu.anthropic.claude-sonnet-4-6`).


All team roles (`gds-aidr-data-scientist`, `gds-aidr-developer`, `gds-aidr-analyst`, `gds-aidr-explorer`) have Bedrock access in the Development account. Bedrock is excluded from the heavy compute deny policy, so no additional IAM policy is needed for roles with `PowerUserAccess`.

For roles with `ReadOnlyAccess` (analyst, explorer), Bedrock invoke permissions are included implicitly via the base policy in the Development account. If this changes in future (e.g. moving to an allowlist model), a dedicated Bedrock policy will need to be created and attached to those roles.

> **Note:** Bedrock access is Development account only. In Staging and Production, all non-admin team roles (ie) are read-only and cannot invoke models.

<!-->> **Future Terraform:** When the IAM model moves to an allowlist approach, a dedicated Bedrock policy should be added to the `iam-centralised` module. The policy JSON is preserved in the commented-out block above for reference.-->

## 4. User setup

### 4.1 Install Claude Code

```zsh
# Install globally via npm
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version
```

> **Node.js requirement:** Claude Code requires Node.js 18 or later. Check with `node --version`.*under review*

### 4.2 Assume into the GDS AIDR Development account

Use your normal AIDR role assumption process:

```zsh
eval $(aws sts assume-role \
  --role-arn "arn:aws:iam:::role/gds-aidr-data-scientist" \
  --role-session-name "ClaudeCodeSession" \
  --serial-number "<YOUR_MFA_SERIAL>" \
  --token-code <YOUR_MFA_CODE> \
  --profile gds-users \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
  --output text | awk '{print "export AWS_ACCESS_KEY_ID="$1"\nexport AWS_SECRET_ACCESS_KEY="$2"\nexport AWS_SESSION_TOKEN="$3}')
unset AWS_PROFILE
```

### 4.3 Option A: Use the setup wizard (recommended)

The simplest way to configure Claude Code for Bedrock:

```zsh
claude
```

At the login prompt:
1. Select **3rd-party platform**
2. Select **Amazon Bedrock**
3. Choose **Credentials already in environment** (since you just assumed your role)
4. The wizard will detect your region, verify which Claude models are available, and let you pin them
5. Configuration is saved to `~/.claude/settings.json` automatically

After initial setup, run `/setup-bedrock` inside Claude Code at any time to change settings.

### 4.4 Option B: Manual configuration (for scripted setups)

If you prefer to set environment variables directly, add these to your shell configuration or export them before running `claude`:

```zsh
# Enable Bedrock integration
export CLAUDE_CODE_USE_BEDROCK=1

# Set region (EU cross-region inference profiles route within EU)
export AWS_REGION=eu-west-2

# Pin to specific model versions (recommended for consistency)
export ANTHROPIC_DEFAULT_SONNET_MODEL='eu.anthropic.claude-sonnet-4-6'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='eu.anthropic.claude-haiku-4-5-20251001-v1:0'
```

Or add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_REGION": "eu-west-2",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "eu.anthropic.claude-sonnet-4-6",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "eu.anthropic.claude-haiku-4-5-20251001-v1:0"
  }
}
```

### 4.5 VS Code extension setup

If you prefer VS Code over the terminal:

1. Install the **Claude Code** extension from the VS Code marketplace
2. Open VS Code settings (`Cmd+,` on Mac)
3. Search for `claudeCode.environmentVariables`
4. Add the following environment variables:

```json
"claudeCode.environmentVariables": [
  { "name": "CLAUDE_CODE_USE_BEDROCK", "value": "1" },
  { "name": "AWS_REGION", "value": "eu-west-2" },
  { "name": "ANTHROPIC_DEFAULT_SONNET_MODEL", "value": "eu.anthropic.claude-sonnet-4-6" }
]
```

> **Important:** You still need to assume your AIDR role before opening VS Code, or have valid AWS credentials in your environment. The VS Code extension uses the same credential chain as the CLI.

## 5. Verifying it works

### 5.1 Check status

Inside Claude Code, run:

```
/status
```

You should see:
- **Provider:** `Amazon Bedrock`
- **Region:** `eu-west-2` (or whichever region you configured)
- **Model:** the Sonnet model you pinned

### 5.2 Test a simple prompt

```
claude "What is 2 + 2?"
```

If you get a response, Bedrock is working.

### 5.3 Test in your project

```zsh
cd ~/path/to/your/project
claude
```

Then try something like:
```
Summarise the structure of this repository
```

## 6. Troubleshooting

### "Credentials expired" or authentication errors

Your STS session has expired (default 4 hours). Re-assume your role:

```zsh
# Re-run the assume-role command from step 4.2
```

### "Access denied" on Bedrock

Check that:
1. The Bedrock access policy is attached to your role
2. The Anthropic models are enabled in the Bedrock console for the Development account
3. You are in the correct region

```zsh
# Verify your identity
aws sts get-caller-identity

# Check if you can list Bedrock models
aws bedrock list-inference-profiles --region eu-west-2
```

### "On-demand throughput isn't supported"

You are using a raw model ID instead of an inference profile. Use the `eu.` prefixed inference profile ID:

```
# Wrong
anthropic.claude-sonnet-4-6

# Right
eu.anthropic.claude-sonnet-4-6
```

### "Model not available in this region"

Not all Claude models are available in all regions. Claude Sonnet 4.6 and Haiku 4.5 are available via EU cross-region inference (`eu.` prefix). For Opus models, you may need `eu-west-1` (Ireland) or the EU cross-region profile.

Check availability:
```zsh
aws bedrock list-inference-profiles \
  --region eu-west-2 \
  --query 'inferenceProfileSummaries[?contains(inferenceProfileId, `anthropic`)]' \
  --output table
```

### Claude Code not found after install

Ensure Node.js 18+ is installed and npm's global bin directory is in your PATH:

```zsh
node --version    # Should be 18+
npm root -g       # Shows global install path
which claude      # Should show the claude binary path
```

## 7. Cost and usage notes

### Billing

- All Bedrock usage is billed to the AWS account you assumed into (gds-aidr-development)
- *under review* Costs are tracked on a per-user basis. You will be able to track your own costs in AWS Cost Explorer
- Bedrock pricing is per-token (input and output tokens are priced separately)
- The EU cross-region inference profile uses the same pricing as in-region

### Budget awareness

- The AIDR monthly budget is capped. Platform admins will get notified when this has been exceeded.
- Budget alerts are configured.
- **Be mindful of large context windows** — sending entire repositories or very large files to Claude Code consumes significant tokens

### Useful notes

- Use the **Development** account for Claude Code usage. Do not assume into staging or production for LLM work.
- Prefer **Sonnet** for day-to-day coding tasks (good balance of capability and cost)
- Use **Haiku** for lightweight tasks like commit message generation (cheaper, faster)
- Opus is available but significantly more expensive — use only when Sonnet is insufficient

#### Verify model availability

```zsh
# Assume into Development account
# Then list available inference profiles
aws bedrock list-inference-profiles \
  --region eu-west-2 \
  --query 'inferenceProfileSummaries[?contains(inferenceProfileId, `anthropic`)].[inferenceProfileId, status]' \
  --output table
```

You should see profiles like `eu.anthropic.claude-sonnet-4-6` listed as `ACTIVE`.

## 8. Reference

### Key environment variables

| Variable | Purpose | Example value |
|---|---|---|
| `CLAUDE_CODE_USE_BEDROCK` | Enable Bedrock as the backend | `1` |
| `AWS_REGION` | AWS region for Bedrock requests | `eu-west-2` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Pin Sonnet model version | `eu.anthropic.claude-sonnet-4-6` |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Pin Haiku model version | `eu.anthropic.claude-haiku-4-5-20251001-v1:0` |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Pin Opus model version | `eu.anthropic.claude-opus-4-8` |
| `DISABLE_PROMPT_CACHING` | Disable prompt caching | `1` |

### Useful Claude Code commands

| Command | Purpose |
|---|---|
| `/status` | Show current provider, region, and model |
| `/setup-bedrock` | Re-run the Bedrock setup wizard |
| `/model` | Switch between available models |
| `/help` | Show all available commands |

### Claude documentation

- Claude Code Bedrock setup: https://code.claude.com/docs/en/amazon-bedrock
- Bedrock inference profiles: https://docs.aws.amazon.com/bedrock/latest/userguide/inference-profiles-support.html
- Bedrock pricing: https://aws.amazon.com/bedrock/pricing/
- Bedrock IAM configuration: https://docs.aws.amazon.com/bedrock/latest/userguide/security-iam.html

### AIDR-specific details

| Item | Value |
|---|---|
| Permitted region | `eu-west-2` (London) |
| EU inference profile prefix | `eu.` |
| Relevant IAM roles | `gds-aidr-data-scientist`, `gds-aidr-developer`, `gds-aidr-analyst`, `gds-aidr-explorer` |


--- 

<!--END-->