output "project_id" {
  description = "The GCP project ID these resources were deployed into."
  value       = data.google_project.project.project_id
}

output "enabled_apis" {
  description = "APIs enabled on the project."
  value       = [for api in google_project_service.apis : api.service]
}

#---------------------------------------------------------------
# VPC
#---------------------------------------------------------------
output "vpc_network_name" {
  description = "Name of the VPC network."
  value       = module.vpc.vpc_name
}

output "vpc_network_self_link" {
  description = "Self link of the VPC network."
  value       = module.vpc.self_link
}

output "subnet_self_links" {
  description = "Self links of the subnets created in the VPC."
  value       = module.vpc.subnet_self_links
}

#---------------------------------------------------------------
# Artifact Registry
#---------------------------------------------------------------
output "artifact_registry_repository_id" {
  description = "ID of the Artifact Registry repository."
  value       = module.artifact_registry.repository_id
}

output "artifact_registry_repository_name" {
  description = "Full name of the Artifact Registry repository."
  value       = module.artifact_registry.repository_name
}

output "container_image" {
  description = "Full path of the container image deployed to Cloud Run."
  value       = "${var.location}-docker.pkg.dev/${data.google_project.project.project_id}/${var.artifact_repository_id}/${var.cloud_run_service_name}:${var.cloud_run_image_tag}"
}

#---------------------------------------------------------------
# Cloud Run
#---------------------------------------------------------------
output "cloud_run_service_name" {
  description = "Name of the Cloud Run service."
  value       = module.cloud_run_service.service_name
}

output "cloud_run_service_url" {
  description = "URL of the Cloud Run service."
  value       = module.cloud_run_service.service_uri
}

output "cloud_run_service_account_email" {
  description = "Email of the Cloud Run service account."
  value       = module.cloud_run_service_account.sa_email
}

output "serverless_neg_id" {
  description = "ID of the serverless network endpoint group."
  value       = module.service_neg.id
}

#---------------------------------------------------------------
# Load Balancer
#---------------------------------------------------------------
output "load_balancer_ip" {
  description = "External IP address of the load balancer."
  value       = module.lb.lb_ip_address
}

output "load_balancer_backend_service_names" {
  description = "Map of load balancer backend service names."
  value       = module.lb.backend_service_names
}

output "domains" {
  description = "Domains served by the load balancer / managed SSL certificate."
  value       = var.domains
}

#---------------------------------------------------------------
# IAP
#---------------------------------------------------------------
output "iap_allowed_members" {
  description = "Members granted IAP access to the backend service."
  value       = var.allowed_iap_members
}