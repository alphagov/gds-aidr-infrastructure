
# Data Lake

This module provisions the central data lake infrastructure for the platform. It creates a secure Amazon S3 bucket to store generated datasets and metadata, with access governed by AWS Lake Formation.

The data lake resides in the Production account. Datasets are read cross-account from the Development and Staging accounts to ensure a single authoritative copy.

<!--date_added:weds-15-jul-2026-->
<!--date_updated:weds-04-nov-2026-->

--- 

## Data lake access

How a member of the team reads the generated datasets, what has to be in place
for that to work, and how to check it.

### Where the data is

One bucket, in the **Production** account:

```
s3://gds-aidr-synthetic-data-library/
  datasets/email/v1/runs/date=YYYY-MM-DD/run_id=<id>/   the data
  metadata/email/v1/runs/date=YYYY-MM-DD/run_id=<id>/   the manifest
```

Every batch run writes one folder under each prefix. The run ID carries its own
start date, so the date partition can always be derived from it rather than
remembered.

A run folder holds the relational tables as CSV, a `messages_flat.csv` for
people who want one table to open, `mailbox_messages.csv` for the per-mailbox
view, and the `.eml` archive as a `.zip`.

### How access is granted

Access is attached to the team role a person already assumes. There is no
separate data-lake role to switch into.

In `modules/iam-centralised/main.tf`, the resource
`aws_iam_role_policy.team_data_lake_read` attaches a read policy to every team
role named in `data_lake_reader_role_names`. It grants:

* `s3:ListBucket` on the bucket
* `s3:GetObject` on the dataset and metadata prefixes
* `kms:Decrypt` and `kms:DescribeKey` on the lake key

The KMS grant matters. The objects are encrypted with a customer managed key,
and the AWS managed `ReadOnlyAccess` policy does not include `kms:Decrypt`, so
without it a read fails with Access Denied even though the S3 permission is
present.

In `environments/production-iam/variables.tf`, `data_lake_reader_role_names`
defaults to:

```hcl
["data-scientist", "developer", "analyst", "explorer"]
```

All four team roles, in all three accounts. So everyone on the team has read
access as soon as they are listed against one of those roles, and so will the
interns when they arrive.

Who holds which role is not in this repository. It is read at plan time from
the SSM parameter `/gds-aidr/iam/team-role-assignments` in the Production
account. To change who has access, change that parameter and apply
`environments/production-iam`.

### Two ways to read it

#### Reading from the Production account

The simplest route, and the one to try first. The bucket is in Production, so
this is a same-account read and needs nothing beyond the team role.

```zsh
aws sts assume-role \
  --role-arn "arn:aws:iam::<PRODUCTION_ACCOUNT_ID>:role/gds-aidr-data-scientist" \
  --role-session-name "read-lake" \
  --serial-number "arn:aws:iam::<GDS_USERS_ACCOUNT_ID>:mfa/<username>" \
  --token-code <MFA_CODE>
```

MFA is required on every team role, so the request fails without
`--serial-number` and `--token-code`.

#### Reading from the Development or Staging account

This is a cross-account read, so three things have to agree: the bucket policy,
the KMS key policy, and the identity policy on the team role. The first two are
built from `reader_account_arns` in the data-lake module. The identity policy is
not enough on its own.

All three were verified in place on 3 November 2026:

| Check | Statement | Covers |
|---|---|---|
| Bucket policy | `AllowCrossAccountRead` | Development, Staging |
| KMS key policy | `AllowCrossAccountDecrypt` | Development, Staging |
| Team role in Development | `gds-aidr-data-lake-read` | bucket, both prefixes, the lake key |

`terraform plan` in `environments/data-lake` reported no changes on the same
date, so the committed configuration and the live policies agree.

Production is deliberately absent from both cross-account statements. The bucket
and the key live in that account, so a role there reads them through its own
identity policy, and the key policy already grants the account root `kms:*`.

Account root in a policy delegates the decision to that account rather than
granting anything directly, so each role there still needs its own read
permission, which `team_data_lake_read` provides.

### Checking access

Three commands, in order. The first that fails says what is wrong.

```zsh
# 1. Which role, in which account
aws sts get-caller-identity

# 2. Can the runs be listed
aws s3 ls s3://gds-aidr-synthetic-data-library/datasets/email/v1/runs/

# 3. Can one be read
aws s3 sync \
  s3://gds-aidr-synthetic-data-library/datasets/email/v1/runs/date=2026-10-08/run_id=<RUN_ID>/ \
  ./<RUN_ID>/
```

What the failures mean:

| Failure | Cause |
|---|---|
| Step 1 fails | No session. Assume the team role first. |
| Step 1 shows the wrong account | Assumed into Development rather than Production. Either switch, or set up the cross-account read above. |
| Step 2 says Access Denied | The role is not in `data_lake_reader_role_names`, or `production-iam` has not been applied since it was, or the person is not against that role in the SSM parameter. |
| Step 2 works but step 3 says Access Denied | Almost always the KMS key rather than S3. Check `kms:Decrypt` on the lake key. |

---


## Mermaid Diagram (data-lake)

```(mermaid)
flowchart LR
  subgraph development ["Development"]
    dcom["Compute"]
  end

  subgraph staging ["Staging"]
    scom["Compute"]
  end

  subgraph production ["Production"]
    pdl["Data Lake S3 Bucket"]
    kms["KMS Encryption Key"]
    lf["Lake Formation"]
    trail["CloudTrail"]
    logs["CloudWatch Logs"]
  end

  dcom -->|reads and writes generated data| pdl
  scom -->|reads authoritative data| pdl

  lf -->|governs access controls| pdl
  pdl -->|encrypted at rest by| kms
  
  pdl -->|logs object-level API activity| trail
  trail -->|delivers audit logs| logs
```

### Infrastructure Components

* **Storage:** A single Amazon S3 bucket for datasets and metadata, separated by logical prefixes.
* **Security:** All public access is explicitly blocked at the bucket level. Data is encrypted at rest using a customer-managed AWS KMS key.
* **Auditing:** Object-level API activity (read and write) is logged via an associated AWS CloudTrail trail directly to Amazon CloudWatch Logs.
* **Governance:** IAM roles and policies are provisioned to allow AWS Lake Formation to register and govern the S3 locations securely.

### Usage

.. code-block:: terraform

```
module "data_lake" {
  source = "../../modules/data-lake"

  bucket_name           = "gds-aidr-data-lake-production"
  production_account_id = "<PRODUCTION_ACCOUNT_ID>"
  role_prefix           = "gds-aidr"

  reader_account_arns = [
    "arn:aws:iam::<DEVELOPMENT_ACCOUNT_ID>:root", # Development account root
    "arn:aws:iam::<STAGING_ACCOUNT_ID>2:root"  # Staging account root
  ]

  tags = {
    Environment = "Production"
    Owner       = "gds-aidr-team"
  }
}

```

### Inputs

* `bucket_name` (string, required): Name of the data lake bucket.
* `production_account_id` (string, required): AWS account ID of the Production account that owns and administers the encryption key.
* `dataset_prefix` (string, optional): Prefix for dataset files. Default is `datasets/email/v1/`.
* `metadata_prefix` (string, optional): Prefix for metadata files. Default is `metadata/email/v1/`.
* `reader_account_arns` (list(string), optional): Account root ARNs permitted to read the lake cross-account, such as the Development and Staging account roots. Default is `[]`.
* `lakeformation_register_role_arn` (string, optional): ARN of an existing role Lake Formation uses to access the registered metadata location. Used when `create_lakeformation_register_role` is false.
* `create_lakeformation_register_role` (bool, optional): Whether this module creates the Lake Formation registration role itself. Default is `true`.
* `role_prefix` (string, optional): Prefix for IAM role names created by this module. Default is `gds-aidr`.
* `audit_log_retention_days` (number, optional): Retention period in days for object-level audit logs. Default is `365`.
* `tags` (map(string), optional): Tags applied to all resources created by the module.

### Outputs

* `bucket_name`: Name of the data lake bucket. Consumed by the data backend repository.
* `bucket_arn`: ARN of the data lake bucket.
* `kms_key_arn`: ARN of the customer-managed AWS KMS encryption key.
* `dataset_prefix`: Prefix used for dataset files.
* `metadata_prefix`: Prefix used for metadata files.
* `audit_log_group`: Name of the Amazon CloudWatch log group containing object-level S3 audit logs.
* `lakeformation_register_role_arn`: ARN of the Lake Formation registration role.


---

<!--END-->