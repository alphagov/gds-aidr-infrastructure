# Security environment

Manages cross-cutting platform security concerns: DNS, wildcard certificate reference, and DNS records for application subdomains across all workload environments.

## Naming convention

Subdomains follow the pattern:

    <environment>-<repository-name>.<domain_name>

Where:
- `<environment>` is `dev`, `staging`, or `prod`
- `<repository-name>` matches the application's repository name exactly

The convention is enforced by construction in `main.tf` — the subdomain is composed from `environment` and `repo_name` fields, not written out as a string.

## Adding a new app-environment

To add a new application or environment, add a map entry to `local.app_environments` in `main.tf`:

    "<environment_full_name>-<repository_name>" = {
      environment        = "<dev|staging|prod>"
      repo_name          = "<repository-name>"
      cloudfront_domain  = data.terraform_remote_state.compute.outputs.<env>_cloudfront_domain_name
      cloudfront_zone_id = data.terraform_remote_state.compute.outputs.<env>_cloudfront_hosted_zone_id
    }

Prerequisites:
1. The compute environment must have a CloudFront distribution for the target environment, with outputs `<env>_cloudfront_domain_name` and `<env>_cloudfront_hosted_zone_id` published.
2. The wildcard ACM certificate (`*.<domain_name>`) must be attached to the target CloudFront distribution — see `modules/cloudfront-waf` inputs `aliases` and `acm_certificate_arn`.

## Apply order

Security depends on compute outputs. Apply order for a new environment:

1. `terraform apply` in `environments/compute` — creates or updates the CloudFront distribution with the custom domain and certificate.
2. `terraform apply` in `environments/security` — creates the DNS record pointing at CloudFront.

## Deferred environments

Staging and Production entries in `local.app_environments` are commented with `# --- STAGING (deferred) ---` and `# --- PRODUCTION (deferred) ---` prefixes. Uncomment when the corresponding CloudFront distributions exist in the compute environment.