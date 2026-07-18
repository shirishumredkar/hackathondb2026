output "vpc_connector_id" { value = google_vpc_access_connector.connector.id }
output "kms_key_id"       { value = google_kms_crypto_key.cloudrun_key.id }
output "cloudrun_sa_email" { value = google_service_account.cloudrun_sa.email }
output "registry_url"     { value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_repo.repository_id}" }
