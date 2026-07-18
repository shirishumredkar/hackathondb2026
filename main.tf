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
  project = var.project_id
  region  = var.region
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

########################################################################################################################################################################
## Setting up the Cloud Run
########################################################################################################################################################################
resource "google_compute_network" "vpc_network" {
  name                    = "cloudrun-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "cloudrun-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_vpc_access_connector" "connector" {
  name          = "cr-vpc-connector"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc_network.name
}

resource "google_kms_key_ring" "keyring" {
  name     = "cloudrun-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "cloudrun_key" {
  name     = "cloudrun-customer-key"
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ENCRYPT_DECRYPT"
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_service_account" "cloudrun_sa" {
  account_id   = "cloud-run-runtime-sa"
  display_name = "Service Account for Cloud Run Execution"
}

resource "google_artifact_registry_repository" "app_repo" {
  location      = var.region
  repository_id = "app-docker-images"
  description   = "Docker repository for Cloud Run images"
  format        = "DOCKER"
  kms_key_name  = google_kms_crypto_key.cloudrun_key.id
}

data "google_project_of_identity" "gcp_sa" {}

resource "google_kms_crypto_key_iam_binding" "kms_binding" {
  crypto_key_id = google_kms_crypto_key.cloudrun_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members = [
    "serviceAccount:service-${data.google_project_of_identity.gcp_sa.project_number}@://gserviceaccount.com",
    "serviceAccount:service-${data.google_project_of_identity.gcp_sa.project_number}@://gserviceaccount.com"
  ]
}
