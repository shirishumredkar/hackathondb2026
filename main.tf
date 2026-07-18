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

# Example resource: A simple VPC
resource "google_compute_network" "vpc_network" {
  name                    = "terraform-network"
  auto_create_subnetworks = true
}
