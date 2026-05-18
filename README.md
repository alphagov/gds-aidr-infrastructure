

<!--date_created: mon-18-may-2026-->
<!--date_updated: mon-18-may-2026-->

```
gds-aidr-infrastructure
├── modules/              # Reusable Gov-standard components
├── environments/
│   ├── dev/              # Dev account overrides
│   │   ├── main.tf       # Source modules/compute
│   │   └── variables.tf
│   └── prod/             # Prod account (mirrored config)
│       ├── main.tf       
│       └── variables.tf

```