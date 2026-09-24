#---------------------------------------------------------------
# Core
#---------------------------------------------------------------
variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "location" {
  description = "Default GCP region for regional resources (Cloud Run, subnet, LB, Artifact Registry)."
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name used for naming/labeling (e.g. dev, staging, prod)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "labels" {
  description = "Common labels applied to resources that support labeling."
  type        = map(string)
  default     = {}
}

#---------------------------------------------------------------
# APIs
#---------------------------------------------------------------
variable "apis_to_enable" {
  description = "List of GCP APIs to enable on the project."
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "run.googleapis.com",
    "iap.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
  ]
}

#---------------------------------------------------------------
# VPC
#---------------------------------------------------------------
variable "vpc_name" {
  description = "Name of the VPC network."
  type        = string
  default     = "vpc"
}

variable "delete_default_routes_on_create" {
  description = "Whether to delete default routes on VPC creation."
  type        = bool
  default     = false
}

variable "subnet_name" {
  description = "Name of the primary subnet."
  type        = string
  default     = "subnet"
}

variable "subnet_cidr" {
  description = "CIDR range for the primary subnet."
  type        = string
  default     = "10.1.0.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid CIDR block."
  }
}

variable "private_ip_google_access" {
  description = "Enable Private Google Access on the subnet."
  type        = bool
  default     = true
}

variable "firewall_name" {
  description = "Name of the ingress firewall rule."
  type        = string
  default     = "vpc-firewall-http"
}

variable "firewall_source_ranges" {
  description = "Source CIDR ranges allowed by the firewall rule. Restrict this in production instead of 0.0.0.0/0 where possible."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "firewall_allowed_ports" {
  description = "List of {protocol, ports} objects allowed by the firewall rule."
  type = list(object({
    protocol = string
    ports    = list(string)
  }))
  default = [
    {
      protocol = "tcp"
      ports    = ["80"]
    }
  ]
}

#---------------------------------------------------------------
# Artifact Registry
#---------------------------------------------------------------
variable "artifact_type" {
  description = "Artifact Registry repository format."
  type        = string
  default     = "DOCKER"
}

variable "artifact_repository_id" {
  description = "Artifact Registry repository ID."
  type        = string
  default     = "nodeapp"
}

variable "artifact_repository_description" {
  description = "Description for the Artifact Registry repository."
  type        = string
  default     = "nodeapp repository"
}

variable "run_image_push_script" {
  description = "Path (relative to module root) to the script that builds and pushes the container image."
  type        = string
  default     = "../src/artifact_push.sh"
}

#---------------------------------------------------------------
# Cloud Run service account
#---------------------------------------------------------------
variable "cloud_run_sa_account_id" {
  description = "Account ID for the Cloud Run service's service account."
  type        = string
  default     = "cloud-run-sa"
}

variable "cloud_run_sa_display_name" {
  description = "Display name for the Cloud Run service's service account."
  type        = string
  default     = "Cloud Run Service Account"
}

variable "cloud_run_sa_permissions" {
  description = "Project-level IAM roles granted to the Cloud Run service account."
  type        = list(string)
  default     = ["roles/artifactregistry.reader"]
}

#---------------------------------------------------------------
# Serverless NEG
#---------------------------------------------------------------
variable "neg_name" {
  description = "Name of the serverless network endpoint group backing the Cloud Run service."
  type        = string
  default     = "service-neg"
}

#---------------------------------------------------------------
# Cloud Run service
#---------------------------------------------------------------
variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service."
  type        = string
  default     = "nodeapp"
}

variable "cloud_run_ingress" {
  description = "Ingress setting for the Cloud Run service."
  type        = string
  default     = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER",
    ], var.cloud_run_ingress)
    error_message = "cloud_run_ingress must be a valid Cloud Run ingress value."
  }
}

variable "cloud_run_deletion_protection" {
  description = "Whether to enable deletion protection on the Cloud Run service."
  type        = bool
  default     = true
}

variable "cloud_run_min_instance_count" {
  description = "Minimum number of Cloud Run instances."
  type        = number
  default     = 2
}

variable "cloud_run_max_instance_count" {
  description = "Maximum number of Cloud Run instances."
  type        = number
  default     = 5
}

variable "cloud_run_max_instance_request_concurrency" {
  description = "Maximum concurrent requests per Cloud Run instance."
  type        = number
  default     = 80
}

variable "cloud_run_container_port" {
  description = "Container port exposed by the Cloud Run service."
  type        = number
  default     = 8080
}

variable "cloud_run_cpu_idle" {
  description = "Whether CPU is allocated only during request processing."
  type        = bool
  default     = true
}

variable "cloud_run_startup_cpu_boost" {
  description = "Whether to enable startup CPU boost."
  type        = bool
  default     = true
}

variable "cloud_run_image_tag" {
  description = "Tag of the container image to deploy (image path is derived from the Artifact Registry repo)."
  type        = string
  default     = "latest"
}

variable "cloud_run_env" {
  description = "Environment variables for the Cloud Run container."
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "cloud_run_invoker_members" {
  description = "Members granted roles/run.invoker on the Cloud Run service. Defaults to allUsers to match the original config; restrict this in production since ingress is already locked to the load balancer."
  type        = list(string)
  default     = ["allUsers"]
}

#---------------------------------------------------------------
# Load Balancer
#---------------------------------------------------------------
variable "lb_name" {
  description = "Name of the load balancer."
  type        = string
  default     = "lb"
}

variable "lb_type" {
  description = "Load balancer type."
  type        = string
  default     = "EXTERNAL"
}

variable "create_proxy_only_subnet" {
  description = "Whether to create a proxy-only subnet for the load balancer."
  type        = bool
  default     = false
}

variable "create_static_ip" {
  description = "Whether to reserve a static IP for the load balancer."
  type        = bool
  default     = true
}

variable "lb_backend_port_name" {
  description = "Named port used by the load balancer backend."
  type        = string
  default     = "http"
}

variable "iap_enabled" {
  description = "Whether IAP is enabled on the load balancer backend."
  type        = bool
  default     = true
}

variable "lb_manage_health_check" {
  description = "Whether the LB module should manage the backend health check (typically false for serverless NEGs)."
  type        = bool
  default     = false
}

variable "domains" {
  description = "List of domains served by the load balancer / managed SSL certificate."
  type        = list(string)
  default     = ["mohitd.xyz"]
}

variable "enable_ssl" {
  description = "Whether to enable HTTPS on the load balancer."
  type        = bool
  default     = true
}

variable "enable_http" {
  description = "Whether to enable HTTP on the load balancer."
  type        = bool
  default     = true
}

variable "managed_ssl_certificate" {
  description = "Whether to provision a Google-managed SSL certificate."
  type        = bool
  default     = true
}

variable "https_redirect" {
  description = "Whether to redirect HTTP traffic to HTTPS."
  type        = bool
  default     = true
}

variable "enable_cloud_armor" {
  description = "Whether to attach a Cloud Armor security policy to the load balancer."
  type        = bool
  default     = false
}

#---------------------------------------------------------------
# IAP access
#---------------------------------------------------------------
variable "allowed_iap_members" {
  description = "Members granted roles/iap.httpsResourceAccessor on the backend service (e.g. [\"user:someone@example.com\", \"group:team@example.com\"])."
  type        = list(string)

  validation {
    condition     = length(var.allowed_iap_members) > 0
    error_message = "allowed_iap_members must contain at least one member."
  }
}

#---------------------------------------------------------------
# Access Context Manager (optional, currently disabled in main.tf)
#---------------------------------------------------------------
variable "org_id" {
  description = "GCP organization ID, used only if creating a new Access Context Manager policy."
  type        = string
  default     = ""
}

variable "access_context_manager_policy_name" {
  description = "Existing Access Context Manager policy name (e.g. \"accessPolicies/123456789\"), used if referencing an existing org-level policy."
  type        = string
  default     = ""
}

variable "trusted_ip_ranges" {
  description = "IP ranges (CIDR) allowed by the trusted access level, if Access Context Manager is enabled."
  type        = list(string)
  default     = []
}