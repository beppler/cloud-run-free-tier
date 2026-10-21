# Cloud Run Free Tier with OpenTofu

This project automates the infrastructure required to run a simple application **100% within the Free Tier** limits of the Google Cloud Platform (GCP) using **OpenTofu**.

To ensure zero costs, this setup forces the application to scale down to zero instances when idle (`min_instance_count = 0`), enforces strict request-based billing (`cpu_idle = true`), and provisions all resources within an eligible US region (`us-central1`).

---

## Folder Structure

The project is split into three logical steps to handle resource lifecycles and OpenTofu's remote backend restrictions (the state storage bucket must physically exist before any backend can initialize):

```text
project-free-tier/
├── README.md               # This instructions file
├── common.tfvars           # Values shared by all three steps
├── backend-setup/          # Step 1: Isolated State Bucket Creation
│   └── main.tf
├── cloud-run-app/          # Step 2: Cloud Run App Deployment (Saves state to GCS)
│   ├── main.tf
│   └── terraform.tfvars    # Optional: container_image
└── domain-mappings/        # Step 3: Optional Custom Domain Mappings via CNAME
    ├── main.tf
    └── terraform.tfvars    # custom_domains
```

---

## Prerequisites

1. **OpenTofu CLI** version **1.8 or later** installed on your local machine.
2. A **Service Account** created in your GCP Console with the following minimum roles assigned:
   - Cloud Run Admin (`roles/run.admin`)
   - Service Account User (`roles/iam.serviceAccountUser`)
   - Storage Admin (`roles/storage.admin`)
3. The downloaded private key file in **JSON** format for your Service Account.

---

## Variable File Configuration

Before running any deployment commands, set your project details. Values shared by all three folders live in a single `common.tfvars` at the project root, and each command below passes it with `-var-file=../common.tfvars`.

### 1. Shared values (common.tfvars)

Create `common.tfvars` in the project root:

```hcl
project_id   = "your-gcp-project-id-here"
bucket_name  = "a-globally-unique-name-for-your-bucket"
service_name = "my-free-tier-application"
```

> ⚠️ **IMPORTANT:**
>
> The `backend "gcs"` blocks of `cloud-run-app/` and `domain-mappings/` read `var.bucket_name` during `tofu init` (OpenTofu 1.8+ early evaluation), so `-var-file=../common.tfvars` must be passed to `tofu init` too. If you change the bucket name later, rerun `tofu init -reconfigure -var-file=../common.tfvars` in those folders.
>
> `backend-setup/` does not use `service_name`, so OpenTofu prints a harmless "Value for undeclared variable" warning there.

### 2. Configure Step 2 (cloud-run-app) — optional

To deploy your own image instead of the default hello container, create `cloud-run-app/terraform.tfvars`:

```hcl
container_image = "us-docker.pkg.dev/cloudrun/container/hello:latest"
```

### 3. Configure Step 3 (domain-mappings)

Create `domain-mappings/terraform.tfvars` to map your custom subdomains to your application:

```hcl
custom_domains = ["mydomain.com", "dashboard.system.net"]
```

---

## Step-by-Step Deployment Guide

Open your terminal in the root folder of the project (`project-free-tier`) and execute the following commands in order:

### Step 0: Set Up Authentication Credentials

Point OpenTofu to your Service Account JSON key credentials.

*On Linux/macOS or Git Bash:*

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/local/key.json"
```

*On Windows (PowerShell):*

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\your\local\key.json"
```

### Step 1: Provision the State Storage Bucket

Navigate to the setup directory, initialize the Google provider, and apply the configuration to create the Google Cloud Storage bucket that will track your infrastructure state:

```bash
cd backend-setup
tofu init -var-file=../common.tfvars
tofu apply -auto-approve -var-file=../common.tfvars
```

### Step 2: Deploy the Free Tier Cloud Run Service

Navigate to your application infrastructure directory. When you execute `tofu init`, OpenTofu will automatically connect to the cloud bucket created in Step 1 to track your remote deployment state:

```bash
cd ../cloud-run-app
tofu init -var-file=../common.tfvars
tofu apply -auto-approve -var-file=../common.tfvars
```

Once Step 2 finishes processing, the terminal output will display a public link (`application_url`).

### Step 3: (Optional) Map Custom Domains

If you have custom domains configured in your variables file, deploy the mappings and point your external DNS records (GoDaddy, Cloudflare, etc.) to `googlehosted.com.` via a **CNAME** record:

```bash
cd ../domain-mappings
tofu init -var-file=../common.tfvars
tofu apply -auto-approve -var-file=../common.tfvars
```

---

## Teardown: How to Destroy Resources

If you want to deactivate the project in the future and remove all assets from Google Cloud to clean up your account:

```bash
# 1. Removes custom domain mappings
cd domain-mappings
tofu destroy -auto-approve -var-file=../common.tfvars

# 2. Removes the Cloud Run application
cd ../cloud-run-app
tofu destroy -auto-approve -var-file=../common.tfvars

# 3. Removes the Cloud Storage bucket (make sure it is empty)
cd ../backend-setup
tofu destroy -auto-approve -var-file=../common.tfvars
```
