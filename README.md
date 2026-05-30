# 2022 DevOps Terraform — AWS Infrastructure as Code

A complete Terraform project that provisions a full AWS environment and automates application deployment through a CI/CD pipeline. Built as a DevOps course project covering VPC networking, compute, storage, IAM, databases, and CI/CD automation.

---

## Architecture Overview

```
GitHub → CodePipeline → CodeBuild (terraform apply) → EC2 (SANDBOX)
                     → CodeDeploy → EC2 (deploys index.html via Apache)
```

The infrastructure is organized into **reusable modules**, **environment configurations**, and a **CI/CD pipeline stack**.

---

## Repository Structure

```
.
├── MODULES/                    # Reusable Terraform modules
│   ├── EC2/                    # EC2 instance provisioning
│   ├── IAM/                    # IAM roles, policies, instance profiles
│   ├── S3/                     # S3 bucket creation
│   ├── VPC/                    # VPC, subnets, security groups
│   ├── USERS/                  # IAM user management
│   ├── dynamodb/               # DynamoDB for Terraform state locking
│   ├── rds/                    # RDS database instance
│   └── FILES/
│       └── userdata.sh         # EC2 bootstrap script
├── environments/
│   ├── SANDBOX/                # Development/test environment
│   └── PRODUCTION/             # Production environment
├── pipelineStacks/             # CI/CD pipeline infrastructure
├── scripts/                    # CodeDeploy lifecycle scripts
├── appspec.yml                 # CodeDeploy deployment specification
├── buildspec.yml               # CodeBuild build instructions
└── index.html                  # Sample app deployed to EC2
```

---

## File Definitions

### Root Files

| File | Description |
|------|-------------|
| `buildspec.yml` | Instructions for AWS CodeBuild. Installs Terraform 1.5.7, then runs `terraform init → validate → plan → apply` on the SANDBOX environment automatically on every pipeline trigger. |
| `appspec.yml` | Instructions for AWS CodeDeploy. Copies `index.html` to `/var/www/html/` on the EC2 instance, and runs lifecycle hook scripts (install dependencies, start/stop Apache). |
| `index.html` | A simple HTML page served by Apache on the EC2 instance. This is the sample application deployed via CodeDeploy. |
| `.gitignore` | Excludes all Terraform state files, `.terraform/` directories, and lock files from version control. |

---

### `scripts/` — CodeDeploy Lifecycle Scripts

| File | Description |
|------|-------------|
| `scripts/install_dependencies` | Runs `yum install -y httpd` to install the Apache web server on the EC2 instance before deployment. |
| `scripts/start_server` | Runs `service httpd start` to start Apache after the app files are deployed. |
| `scripts/stop_server` | Checks if Apache is running and stops it (`service httpd stop`) before a new deployment begins. |

---

### `MODULES/VPC/`

| File | Description |
|------|-------------|
| `vpc.tf` | Creates the core networking: VPC, 2 public subnets, 1 private subnet, an Internet Gateway, and a Route Table that routes all outbound traffic (`0.0.0.0/0`) through the gateway. Associates the route table with public subnet 1. |
| `security_groups.tf` | Creates a Security Group that allows **all inbound and outbound traffic** (`-1` protocol, `0.0.0.0/0`). Intended for learning/dev use — tighten this for production. |
| `variables.tf` | Defines all VPC inputs: `vpc_cidr_block` (required), `subnet_cidr_private` (required), subnet CIDRs for public subnets (default: `10.10.10.0/24`, `10.10.20.0/24`), availability zones (default: `us-east-1a/b/c`). |
| `outputs.tf` | Exports `public_subnet_1_id`, `public_subnet_2_id`, and `security_group_id` for use by other modules (EC2, RDS). |

---

### `MODULES/EC2/`

| File | Description |
|------|-------------|
| `ec2.tf` | Creates a single EC2 instance: uses the latest Amazon Linux 2 AMI, places it in a public subnet, attaches a security group and IAM instance profile, assigns a public IP, and runs `userdata.sh` on first boot. Tagged `Name = "SampleApp"` so CodeDeploy can find it. |
| `data-sources.tf` | Queries AWS for the most recent Amazon Linux 2 AMI (`amzn2-ami-hvm-*-x86_64-gp2`) owned by Amazon. The result is used by `ec2.tf` to always launch the latest version. |
| `variables.tf` | Inputs: `environment`, `instance_type` (default: `t2.micro`), `public_subnet_1`, `ssh_key_name` (default: `jenkins-key`), `ebs_optimized` (default: false), `security_group` (list), `instance_profile`. |

---

### `MODULES/IAM/`

| File | Description |
|------|-------------|
| `iam.tf` | Creates an IAM Role for EC2 with a trust policy allowing `ec2.amazonaws.com` to assume it. Attaches an IAM Policy granting full S3 access (`s3:*`). Creates an Instance Profile that wraps the role so EC2 can use it. |
| `variables.tf` | Inputs: `environment` (used to name resources uniquely), `bucket_arn` (commented out — reserved for scoped S3 access). |
| `outputs.tf` | Exports `radys_fridge` — the Instance Profile ID, passed to the EC2 module via `instance_profile`. |

---

### `MODULES/S3/`

| File | Description |
|------|-------------|
| `s3.tf` | Conditionally creates an S3 bucket (only if `create_s3 = true`). Bucket name is built as `{environment}-ziyotek-{bucket_name}-{region}-{index}`. Supports versioning toggle and `force_destroy`. |
| `data.tf` | Fetches the current AWS region using `aws_region` data source. Used to include region in the bucket name. |
| `variables.tf` | Inputs: `bucket_name` (default: `mys3backendstate`), `environment`, `versioning` (bool, default: false), `create_s3` (bool, default: false). |
| `outputs.tf` | S3 ARN output is commented out — can be uncommented when needed by IAM policies. |

---

### `MODULES/dynamodb/`

| File | Description |
|------|-------------|
| `dynamodb.tf` | Creates a DynamoDB table named `{environment}-terraform-lock` with a `LockID` string hash key. Used as a **Terraform state lock** — prevents two people or pipelines from running `terraform apply` at the same time. |
| `variable.tf` | Inputs: `environment`, `read_capacity` (default: 20), `write_capacity` (default: 20). |

---

### `MODULES/rds/`

| File | Description |
|------|-------------|
| `rds.tf` | Creates a PostgreSQL RDS instance (`db.t3.micro`, 10GB). Generates a random 16-character password and stores it in **AWS SSM Parameter Store** at `/devops2022/database/password` as a SecureString. Creates a DB Subnet Group. |
| `variables.tf` | Inputs: `db_engine` (default: `postgres`), `db_username` (default: `admin1`), `db_name` (default: `mydb`), `engine_version` (default: `10.21`), `instance_class`, `security_group`, `rds_subnets` (list). |

---

### `MODULES/USERS/`

| File | Description |
|------|-------------|
| `users.tf` | Creates IAM users conditionally — **only** when `environment == "prod"` AND `create_users == true`. Creates one user per name in the `user_names` list using `count`. |
| `variables.tf` | Inputs: `environment`, `user_names` (list, default: `["user1", "user2", "user3"]`), `create_users` (bool, default: false). |
| `ima.tf` | Placeholder file for IAM-related resources in the users module. |

---

### `MODULES/FILES/`

| File | Description |
|------|-------------|
| `userdata.sh` | Bootstrap script run on EC2 first launch. Updates the OS, installs Ruby and AWS CLI, then downloads and installs the **CodeDeploy agent** from the official AWS S3 bucket. This is required for CodeDeploy to be able to deploy to the instance. |

---

### `environments/SANDBOX/`

The development/test environment. Wires modules together for a non-production deployment.

| File | Description |
|------|-------------|
| `provider.tf` | Configures the AWS provider (`us-east-1`) and the **S3 remote backend** for Terraform state. **⚠️ Replace `YOUR_TERRAFORM_STATE_BUCKET` with your own S3 bucket before running.** |
| `variables.tf` | Defines `environment` variable (default: `"MyDemoApplication"`). |
| `vpc.tf` | Calls the VPC module with CIDR `10.10.0.0/16` and private subnet `10.10.30.0/24`. |
| `ec2.tf` | Calls the EC2 module, wiring in the VPC security group, public subnet, and IAM instance profile. |
| `iam.tf` | Calls the IAM module to create the EC2 role and instance profile. |
| `dynamodb.tf` | DynamoDB state lock table — commented out (create manually before first run). |
| `rds.tf` | RDS database — commented out by default. Uncomment to provision a database. |
| `s3.tf` | S3 bucket — commented out by default. Uncomment to create application buckets. |
| `users.tf` | IAM users — commented out by default (users are only created in prod). |

---

### `environments/PRODUCTION/`

The production environment. Same module structure as SANDBOX with production-grade settings.

| File | Description |
|------|-------------|
| `provider.tf` | AWS provider for production. No S3 backend configured — add one before using. |
| `variables.tf` | Sets `environment = "prod"` and `instance_type = "t2.small"` (larger than sandbox). |
| `vpc.tf` | VPC with same CIDR as SANDBOX. Adjust CIDRs if both environments run simultaneously. |
| `ec2.tf` | EC2 instance — no IAM profile attached (unlike SANDBOX). |
| `dynamodb.tf` | Calls DynamoDB module for prod state locking. |
| `s3.tf` | Creates an S3 bucket in production. |
| `users.tf` | Calls the USERS module — IAM users will be created since `environment = "prod"`. |

---

### `pipelineStacks/`

Provisions the full CI/CD pipeline infrastructure.

| File | Description |
|------|-------------|
| `provider.tf` | AWS provider for the pipeline stack (`us-east-1`). Add a remote backend here for team use. |
| `variables.tf` | Pipeline inputs: `GitHubOwner` (default: `Abrorjon77`) and `GitHubRepo` (default: `2022-devops-terraform`). |
| `data.tf` | Reads the GitHub OAuth token from SSM Parameter Store at `/github/authorization-token`. This token is used to authenticate CodePipeline with GitHub. |
| `s3.tf` | References an existing S3 bucket (`abrorjoncodepipelines3bucket`) as the artifact store. **Replace with your own bucket name.** |
| `codepipeline.tf` | Creates the CodePipeline with 3 stages: **Source** (pulls from GitHub `main` branch), **Build** (triggers CodeBuild), **Deploy** (triggers CodeDeploy to `MyDeploymentGroup`). |
| `codebuild.tf` | Creates the CodeBuild project that runs `buildspec.yml`. Uses Amazon Linux 2 `standard:4.0` image. Grants the build role full permissions for EC2, S3, SSM, IAM, and logging. |
| `codedeploy.tf` | Creates the CodeDeploy application (`MyDemoApplication`) and deployment group (`MyDeploymentGroup`). Targets EC2 instances tagged `Name = "SampleApp"`. |

---

## How to Use

### Prerequisites

1. **Install Terraform 1.5.7**
   ```bash
   curl -qL -o terraform.zip https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
   unzip terraform.zip && mv terraform /usr/local/bin/
   terraform version
   ```

2. **Configure AWS credentials**
   ```bash
   aws configure
   # AWS Access Key ID, Secret Access Key, Region: us-east-1
   ```

3. **Create your S3 backend bucket** (one-time setup)
   ```bash
   aws s3 mb s3://your-unique-bucket-name --region us-east-1
   # Enable versioning (recommended)
   aws s3api put-bucket-versioning \
     --bucket your-unique-bucket-name \
     --versioning-configuration Status=Enabled
   ```

---

### Option A — Deploy Infrastructure Only (SANDBOX)

Use this to provision VPC + EC2 + IAM without the CI/CD pipeline.

**Step 1:** Set your S3 backend bucket in `environments/SANDBOX/provider.tf`:
```hcl
backend "s3" {
  bucket = "your-unique-bucket-name"   # ← change this
  key    = "dags/myfile"
  region = "us-east-1"
}
```

**Step 2:** Run Terraform
```bash
cd environments/SANDBOX
terraform init      # downloads providers and modules
terraform validate  # checks syntax
terraform plan      # previews resources to be created
terraform apply     # creates AWS resources (type 'yes' to confirm)
```

**Step 3:** To tear everything down
```bash
terraform destroy
```

---

### Option B — Deploy Full CI/CD Pipeline

Use this to set up automatic deployments triggered by GitHub pushes.

**Step 1:** Create an S3 bucket for pipeline artifacts
```bash
aws s3 mb s3://your-pipeline-artifacts-bucket --region us-east-1
```

**Step 2:** Store your GitHub OAuth token in SSM
```bash
aws ssm put-parameter \
  --name "/github/authorization-token" \
  --value "YOUR_GITHUB_OAUTH_TOKEN" \
  --type SecureString \
  --region us-east-1
```
> Generate a GitHub token at: https://github.com/settings/tokens — needs `repo` scope.

**Step 3:** Update the artifact bucket reference in `pipelineStacks/s3.tf`:
```hcl
data "aws_s3_bucket" "artifact_bucket" {
  bucket = "your-pipeline-artifacts-bucket"   # ← change this
}
```

**Step 4:** Update GitHub owner/repo in `pipelineStacks/variables.tf` if you forked the repo:
```hcl
variable "GitHubOwner" { default = "your-github-username" }
variable "GitHubRepo"  { default = "2022-devops-terraform" }
```

**Step 5:** Deploy the pipeline
```bash
cd pipelineStacks
terraform init
terraform apply
```

Once applied, every push to the `main` branch will automatically:
1. Pull the latest code from GitHub
2. Run `terraform apply` on the SANDBOX environment
3. Deploy `index.html` to the EC2 instance via CodeDeploy

---

### Option C — Enable Optional Modules

To enable RDS, S3, or IAM Users in SANDBOX, uncomment the relevant module blocks:

**Enable RDS database** — in `environments/SANDBOX/rds.tf`:
```hcl
module "rds" {
    source         = "../../MODULES/rds"
    environment    = var.environment
    security_group = [module.vpc.security_group_id]
    rds_subnets    = [module.vpc.public_subnet_1_id, module.vpc.public_subnet_2_id]
}
```

**Enable S3 bucket** — in `environments/SANDBOX/s3.tf`:
```hcl
module "s3" {
    source    = "../../MODULES/S3"
    environment = var.environment
    create_s3 = true
}
```

---

## Key Variables Reference

| Variable | Location | Default | Description |
|----------|----------|---------|-------------|
| `environment` | `environments/SANDBOX/variables.tf` | `MyDemoApplication` | Tags all resources and names them |
| `vpc_cidr_block` | `environments/SANDBOX/vpc.tf` | `10.10.0.0/16` | VPC IP range |
| `instance_type` | `MODULES/EC2/variables.tf` | `t2.micro` | EC2 size (use `t2.small` for prod) |
| `ssh_key_name` | `MODULES/EC2/variables.tf` | `jenkins-key` | Name of your AWS key pair for SSH access |
| `GitHubOwner` | `pipelineStacks/variables.tf` | `Abrorjon77` | Your GitHub username |
| `GitHubRepo` | `pipelineStacks/variables.tf` | `2022-devops-terraform` | Your GitHub repo name |

---

## AWS Resources Created

| Resource | Module | Count |
|----------|--------|-------|
| VPC | VPC | 1 |
| Subnets (public x2, private x1) | VPC | 3 |
| Internet Gateway + Route Table | VPC | 1 each |
| Security Group (allow all) | VPC | 1 |
| EC2 Instance (Amazon Linux 2) | EC2 | 1 |
| IAM Role + Policy + Instance Profile | IAM | 1 each |
| S3 Bucket (optional) | S3 | 0–1 |
| DynamoDB Table (state lock) | dynamodb | 1 |
| RDS PostgreSQL Instance (optional) | rds | 0–1 |
| IAM Users (prod only, optional) | USERS | 0–3 |
| CodePipeline | pipelineStacks | 1 |
| CodeBuild Project | pipelineStacks | 1 |
| CodeDeploy App + Deployment Group | pipelineStacks | 1 each |

---

## Cost Warning

Some resources incur AWS charges:
- **EC2** (`t2.micro`) — free tier eligible for 12 months
- **RDS** (`db.t3.micro`) — free tier eligible, but charges apply outside free tier
- **DynamoDB** — free tier eligible (25GB, 25 RCU/WCU)
- **S3** — minimal cost for state storage

Always run `terraform destroy` when done to avoid unexpected charges.

---

## Fixes Applied

See [FIXES.md](./FIXES.md) for a list of bugs that were identified and corrected from the original repository.

---

## Running the SANDBOX Infrastructure

### Before You Start (one-time setup)

**1. Create your S3 bucket for Terraform state**
```bash
aws s3 mb s3://your-name-terraform-state --region us-east-1
```

**2. Update the bucket name in the code**

Open `environments/SANDBOX/provider.tf` and replace:
```hcl
bucket = "YOUR_TERRAFORM_STATE_BUCKET"
```
with your actual bucket name.

---

### Running It

```bash
cd environments/SANDBOX

terraform init
```
Downloads the AWS provider plugin and connects to your S3 backend. You'll see:
```
Initializing modules...
Initializing the backend...
Successfully configured the backend "s3"!
```

```bash
terraform plan
```
Shows you exactly what AWS will create — no changes made yet. Safe to run anytime.

```bash
terraform apply
```
Type `yes` when prompted. Takes about **2–3 minutes**.

---

### What Happens When You Run It

#### 1. VPC is created first
Terraform builds the network that everything else lives inside:
- A VPC with IP range `10.10.0.0/16`
- Two public subnets (`10.10.10.0/24`, `10.10.20.0/24`) in `us-east-1a` and `us-east-1b`
- One private subnet (`10.10.30.0/24`) in `us-east-1c`
- An Internet Gateway so the EC2 instance can reach the internet
- A Route Table that sends all outbound traffic through the gateway
- A Security Group that allows **all traffic in and out** (open for learning purposes)

#### 2. IAM Role is created
- An IAM Role that EC2 is allowed to assume
- A Policy granting full S3 access
- An Instance Profile that wraps the role — this is what gets attached to EC2

#### 3. EC2 instance is launched
- Finds the latest Amazon Linux 2 AMI automatically
- Launches a `t2.micro` instance in public subnet 1
- Attaches the IAM Instance Profile (so the instance can access S3)
- Assigns a public IP address
- Runs `userdata.sh` on first boot, which:
  - Updates the OS (`yum update`)
  - Installs Ruby and AWS CLI
  - Downloads and installs the **CodeDeploy agent** from AWS
  - The agent sits running in the background, waiting for deployment instructions

#### 4. Terraform saves state to S3
After apply completes, a `dags/myfile` file is written to your S3 bucket. This is the Terraform state file — it tracks every resource that was created so future `plan`/`apply`/`destroy` commands know what already exists.

---

### What You'll See in AWS Console After Apply

| Service | What's There |
|---------|-------------|
| **VPC** | 1 VPC, 3 subnets, 1 IGW, 1 route table, 1 security group |
| **EC2** | 1 running instance tagged `SampleApp`, with a public IP |
| **IAM** | 1 role, 1 policy, 1 instance profile all named `MyDemoApplication-*` |
| **S3** | Your state bucket now has a `dags/myfile` object in it |

---

### What Does NOT Run by Default

These are commented out in SANDBOX and won't be created unless you uncomment them:

| Module | Why it's off | Cost if enabled |
|--------|-------------|-----------------|
| **RDS** | Slow to create (~10 min), costs money | ~$15–25/month |
| **S3 app bucket** | Not needed for basic demo | Minimal |
| **DynamoDB state lock** | Create manually before first run | Free tier |
| **IAM Users** | Only meant for prod environment | Free |

---

### To Tear Everything Down
```bash
terraform destroy
```
Type `yes`. Deletes the EC2 instance, VPC, IAM resources — everything Terraform created. Takes about 2 minutes. **Your S3 state bucket is NOT deleted** (it was created outside Terraform).

---

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `No valid credential sources` | AWS CLI not configured | Run `aws configure` |
| `BucketNotFound` | State bucket doesn't exist yet | Create it with `aws s3 mb` |
| `InvalidKeyPair.NotFound: jenkins-key` | No key pair named `jenkins-key` in your AWS account | Create one in EC2 Console → Key Pairs, or change `ssh_key_name` in `MODULES/EC2/variables.tf` |
| `error configuring S3 Backend` | Wrong bucket name in `provider.tf` | Double-check the bucket name and region |

---

## Running the Pipeline Stack in AWS

This sets up the full CI/CD automation — every push to GitHub automatically runs `terraform apply` and deploys the app to EC2.

### Prerequisites — Do These First

The pipeline stack **depends on the SANDBOX infrastructure already existing**. Run that first if you haven't:
```bash
cd environments/SANDBOX
terraform init && terraform apply
```

---

### Step 1 — Fork the Repo

Go to GitHub and fork `Abrorjon77/2022-devops-terraform` to your own account. The pipeline needs to point to **your** repo so it can pull code and trigger on your pushes.

---

### Step 2 — Create a GitHub OAuth Token

1. Go to **GitHub → Settings → Developer Settings → Personal Access Tokens → Tokens (classic)**
2. Click **Generate new token**
3. Give it a name like `codepipeline-token`
4. Check the **`repo`** scope (full repo access)
5. Click **Generate token** and copy it — you won't see it again

---

### Step 3 — Store the Token in AWS SSM

```bash
aws ssm put-parameter \
  --name "/github/authorization-token" \
  --value "ghp_yourtokenhere" \
  --type SecureString \
  --region us-east-1
```

Verify it was saved:
```bash
aws ssm get-parameter \
  --name "/github/authorization-token" \
  --with-decryption \
  --region us-east-1
```

---

### Step 4 — Create the Artifact S3 Bucket

CodePipeline needs a bucket to pass files between stages (source → build → deploy):
```bash
aws s3 mb s3://your-pipeline-artifacts-bucket --region us-east-1

# Enable versioning (required by CodePipeline)
aws s3api put-bucket-versioning \
  --bucket your-pipeline-artifacts-bucket \
  --versioning-configuration Status=Enabled
```

---

### Step 5 — Update the Code

**`pipelineStacks/s3.tf`** — point to your artifact bucket:
```hcl
data "aws_s3_bucket" "artifact_bucket" {
  bucket = "your-pipeline-artifacts-bucket"   # ← your bucket
}
```

**`pipelineStacks/variables.tf`** — point to your forked repo:
```hcl
variable "GitHubOwner" { default = "your-github-username" }
variable "GitHubRepo"  { default = "2022-devops-terraform" }
```

**`environments/SANDBOX/provider.tf`** — make sure your state bucket is set:
```hcl
bucket = "your-terraform-state-bucket"
```

---

### Step 6 — Deploy the Pipeline

```bash
cd pipelineStacks
terraform init
terraform plan    # review what will be created
terraform apply   # type 'yes'
```

Takes about **1–2 minutes**. Creates ~8 AWS resources.

---

### What Gets Created

```
CodePipeline  ──►  CodeBuild Project  ──►  CodeDeploy App
     │                    │                      │
     │            runs buildspec.yml      targets EC2 tagged
     │            (terraform apply)         "SampleApp"
     │
  pulls from
  GitHub main
```

| Resource | Name | Purpose |
|----------|------|---------|
| CodePipeline | `tf-test-pipeline` | Orchestrates the 3 stages |
| IAM Role | `pipeline-role-devops-2022` | Allows pipeline to access S3, CodeBuild, CodeDeploy |
| CodeBuild Project | `codebuild-project` | Runs Terraform inside a container |
| IAM Role | `codebuild-role-devops-2022` | Allows CodeBuild to create AWS resources |
| CodeDeploy App | `MyDemoApplication` | The deployment application |
| CodeDeploy Group | `MyDeploymentGroup` | Targets EC2 tagged `Name=SampleApp` |
| IAM Role | `deploy-role-devops-2022` | Allows CodeDeploy to reach EC2 |

---

### What Happens on Every Git Push

```
You run: git push origin main
         │
         ▼
┌─────────────────┐
│  Stage 1: Source │  CodePipeline detects the push via GitHub webhook
│                  │  Downloads your repo as a zip into the S3 artifact bucket
└────────┬─────────┘
         │
         ▼
┌─────────────────┐
│  Stage 2: Build  │  CodeBuild spins up an Amazon Linux 2 container
│                  │  Installs Terraform 1.5.7
│                  │  Runs: terraform init
│                  │         terraform validate
│                  │         terraform plan
│                  │         terraform apply -auto-approve
│                  │  Any infra changes in your code are applied to SANDBOX
└────────┬─────────┘
         │
         ▼
┌─────────────────┐
│  Stage 3: Deploy │  CodeDeploy finds the EC2 instance tagged "SampleApp"
│                  │  Runs: scripts/stop_server   (stops Apache)
│                  │         scripts/install_dependencies (installs httpd)
│                  │         copies index.html → /var/www/html/
│                  │         scripts/start_server  (starts Apache)
│                  │  Your app is live at the EC2 public IP
└─────────────────┘
```

Total time from `git push` to live: **~5–8 minutes**

---

### How to Verify It Worked

**Check pipeline status in AWS Console:**
- Go to **CodePipeline → tf-test-pipeline**
- All 3 stages should show green ✅

**Check the deployed app:**
```bash
# Get the EC2 public IP
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=SampleApp" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text

# Open in browser
http://YOUR_EC2_PUBLIC_IP
```

You should see the blue HTML page: *"Congratulations Mr Abrorjon DevOps"*

---

### To Destroy the Pipeline

```bash
cd pipelineStacks
terraform destroy
```

This removes CodePipeline, CodeBuild, CodeDeploy, and IAM roles — but **does not destroy** the SANDBOX infrastructure (EC2, VPC, etc.). To remove that too:

```bash
cd environments/SANDBOX
terraform destroy
```

---

### Common Pipeline Errors

| Error | Where | Fix |
|-------|-------|-----|
| `OAuthToken not valid` | Stage 1 Source | GitHub token expired or wrong SSM key name — re-run Step 3 |
| `Repository not found` | Stage 1 Source | Check `GitHubOwner` and `GitHubRepo` match your fork exactly |
| `Error: No valid credential` | Stage 2 Build | CodeBuild IAM role missing permissions — check `codebuild.tf` policy |
| `No instances found` | Stage 3 Deploy | EC2 not tagged correctly or SANDBOX not applied first — check EC2 tag `Name=SampleApp` |
| `Access Denied to S3` | Any stage | Artifact bucket name mismatch in `s3.tf` |
