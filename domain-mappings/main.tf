terraform {
  # Variables in the backend block require OpenTofu >= 1.8 (early evaluation).
  required_version = ">= 1.8"

  backend "gcs" {
    bucket = var.bucket_name
    prefix = "cloud-run-app-domains/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "bucket_name" {
  type        = string
  description = "The state bucket created in backend-setup"
}

variable "service_name" {
  type        = string
  description = "The name of your Cloud Run service"
}

variable "custom_domains" {
  type        = list(string)
  description = "List of external custom domains pointing to this service via CNAME"
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

# Maps each domain in the list to your Cloud Run service
resource "google_cloud_run_v2_domain_mapping" "custom_domains" {
  for_each = toset(var.custom_domains)

  name     = each.value
  location = "us-central1" # Must be the same region as the Cloud Run service

  spec {
    route_name = var.service_name
  }
}
