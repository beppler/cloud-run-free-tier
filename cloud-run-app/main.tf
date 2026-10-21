terraform {
  # IMPORTANT: OpenTofu requires this block to be static.
  # Manually enter the SAME bucket name below that you use in your backend-setup .tfvars file.
  backend "gcs" {
    bucket = "replace-with-your-unique-bucket-name"
    prefix = "cloud-run-app/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "project_id" {
  type = string
  description = "Your GCP project ID"
}

variable "service_name" {
  type = string
  description = "The name of the Cloud Run service"
}

variable "container_image" {
  type        = string
  description = "The full URL of the Docker image for Cloud Run"
  default     = "us-docker.pkg.dev/cloudrun/container/hello:latest"
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

resource "google_cloud_run_v2_service_iam_binding" "public_access" {
  name     = google_cloud_run_v2_service.free_app.name
  location = google_cloud_run_v2_service.free_app.location
  role     = "roles/run.invoker"
  members  = ["allUsers"]
}

resource "google_cloud_run_v2_service" "free_app" {
  name                = var.service_name
  location            = "us-central1" # Mandatory for the Free Tier
  deletion_protection = false

  template {
    scaling {
      min_instance_count = 0   # Turns off unused apps (essential for the free version)
      max_instance_count = 5   # Avoid cost spikes from attacks
    }

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello:latest"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true # Only charge for active requests
      }
    }
  }
}

output "application_url" {
  value = google_cloud_run_v2_service.free_app.uri
}
