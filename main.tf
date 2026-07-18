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
resource "google_project_service" "required_apis" {
  for_each = toset([
    "iamcredentials.googleapis.com",
    "storage.googleapis.com",
    "compute.googleapis.com",
    "vpcaccess.googleapis.com",
    "iam.googleapis.com",
    "cloudkms.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

########################################################################################################################################################################
## Providing TF service account Accessa
########################################################################################################################################################################
##resource "google_project_iam_member" "pipeline_run_admin" {
##  project = var.project_id
##  role    = "roles/run.admin"
##  member  = "serviceAccount:tf-github-actions@project-495bdca4-ac50-4df5-bb6.iam.gserviceaccount.com"
##}

########################################################################################################################################################################
## Setting up the Cloud Run Infrastructure
########################################################################################################################################################################
resource "google_compute_network" "vpc_network" {
  project                 = var.project_id
  name                    = "cloudrun-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required_apis]
}

resource "google_compute_subnetwork" "subnet" {
  project       = var.project_id
  name          = "cloudrun-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

resource "google_vpc_access_connector" "connector" {
  project       = var.project_id
  name          = "cr-vpc-connector"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc_network.name
  depends_on    = [google_project_service.required_apis]
}

resource "google_kms_key_ring" "keyring" {
  project    = var.project_id
  name       = "cloudrun-keyring"
  location   = var.region
  depends_on = [google_project_service.required_apis]
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
  project      = var.project_id
  account_id   = "cloud-run-runtime-sa"
  display_name = "Service Account for Cloud Run Execution"
  depends_on   = [google_project_service.required_apis]
}

data "google_project" "gcp_sa" {}

# FIXED: Replaced standard broad bindings with safe, non-privileged individual target assignments
resource "google_kms_crypto_key_iam_member" "compute_kms" {
  crypto_key_id = google_kms_crypto_key.cloudrun_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.gcp_sa.number}@compute-system.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "registry_kms" {
  crypto_key_id = google_kms_crypto_key.cloudrun_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.gcp_sa.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "registry_kms_servless" {
  crypto_key_id = google_kms_crypto_key.cloudrun_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.gcp_sa.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

resource "google_artifact_registry_repository" "app_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "app-docker-images"
  description   = "Docker repository for Cloud Run images"
  format        = "DOCKER"
  kms_key_name  = google_kms_crypto_key.cloudrun_key.id
  
  depends_on    = [
    google_project_service.required_apis,
    google_kms_crypto_key_iam_member.registry_kms
  ]
}

########################################################################################################################################################################
## Creating Secret for CLoud RUn cnfig
########################################################################################################################################################################
# 1. Create a single secret for the entire .env profile
resource "google_secret_manager_secret" "app_env" {
  secret_id = "app-env-config"
  replication {
    auto {}
  }
}

# 2. Grant Access Permissions to Cloud Run SA for this single secret
resource "google_secret_manager_secret_iam_member" "run_secret_access" {
  secret_id = google_secret_manager_secret.app_env.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:cloud-run-runtime-sa@project-495bdca4-ac50-4df5-bb6.iam.gserviceaccount.com"
}

