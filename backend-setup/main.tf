variable "project_id" {
  type        = string
  description = "Your GCP project ID"
}

variable "bucket_name" {
  type        = string
  description = "Your unique global bucket name for the OpenTofu state"
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

# Create the bucket in the US, in accordance with Free Tier rules.
resource "google_storage_bucket" "tf_state" {
  name                     = var.bucket_name
  location                 = "us-central1" # Mandatory for the Free Tier
  force_destroy            = false
  public_access_prevention = "enforced"
  versioning {
    enabled = true
  }
}
