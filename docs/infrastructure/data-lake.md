
# Data Lake

This module provisions the central data lake infrastructure for the platform. It creates a secure Amazon S3 bucket to store generated datasets and metadata, with access governed by AWS Lake Formation.

The data lake resides in the Production account. Datasets are read cross-account from the Development and Staging accounts to ensure a single authoritative copy.

<!--date_added:weds-15-jul-2026-->
<!--date_updated:weds-15-jul-2026-->

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