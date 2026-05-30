# Fixes Applied

The following bugs were fixed in this repository:

## 1. `MODULES/S3/variables.tf` — Uncommented `create_s3` variable
The `create_s3` variable was commented out but used in `s3.tf`. It is now active with a default of `false`.

## 2. `environments/SANDBOX/provider.tf` — Replaced hardcoded S3 backend bucket
The backend bucket `abrorjoncodepipelines3bucket` was a personal bucket. 
**Before running terraform init, replace `YOUR_TERRAFORM_STATE_BUCKET` with your own S3 bucket name.**

## 3. `MODULES/rds/variables.tf` — Fixed `rds_subnets` type
Changed `default = ""` (string) to `default = []` (list), matching what `subnet_ids` expects.

## 4. `pipelineStacks/data.tf` — Fixed SSM parameter name typo
`/github/authorzation-token` → `/github/authorization-token`

Store your GitHub OAuth token with:
```bash
aws ssm put-parameter \
  --name "/github/authorization-token" \
  --value "YOUR_GITHUB_TOKEN" \
  --type SecureString
```

## 5. `pipelineStacks/codebuild.tf` — Updated deprecated CodeBuild image
`amazonlinux2-x86_64-standard:1.0` → `amazonlinux2-x86_64-standard:4.0`

## 6. `MODULES/USERS/ima.tf` — Fixed empty file
Added a comment placeholder so Terraform doesn't choke on an empty `.tf` file.
