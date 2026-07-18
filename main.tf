########################################################################################################################################################################
## Provider Setup
########################################################################################################################################################################
terraform {
  required_version = ">= 1.0.0"
  backend "gcs" {
    bucket = "hackathondb2026-terraform-state-bucket"
    prefix = "terraform/state"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "project-495bdca4-ac50-4df5-bb6"
  region  = "us-central1"
}

########################################################################################################################################################################
## Enabling the API Services
########################################################################################################################################################################
resource "google_project_service" "iamcredentials" {
  project = "272907652960"  
  service = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "required_apis" {
  for_each = toset([
    "iamcredentials.googleapis.com",
    "storage.googleapis.com",
    "compute.googleapis.com",
  ])
  project = "272907652960"
  service = each.key

  disable_on_destroy = false
}

