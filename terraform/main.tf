# Getting project information
data "google_project" "project" {}

#---------------------------------------------------------------
# Enable Required APIs
#---------------------------------------------------------------

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "iap.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com"
  ])
  disable_on_destroy = false
  project = var.project_id
  service = each.key
}

#---------------------------------------------------------------
# VPC Configuration
#---------------------------------------------------------------

module "vpc" {
  source                          = "./modules/vpc"
  vpc_name                        = "vpc"
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  region                          = var.location
  subnets = [
    {
      name                     = "subnet"
      region                   = var.location
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = true
      ip_cidr_range            = "10.1.0.0/24"
    }
  ]
  firewall_data = [
    {
      name          = "vpc-firewall-ssh"
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    },
    {
      name          = "vpc-firewall-http"
      source_ranges = ["0.0.0.0/0"]
      allow_list = [
        {
          protocol = "tcp"
          ports    = ["80"]
        }
      ]
    },
  ]
}

#---------------------------------------------------------------
# OAuth Brand and IAP Configuration
#---------------------------------------------------------------

resource "google_iap_brand" "project_brand" {
  count = 1
  
  support_email     = "support@mohitcloud.xyz"
  application_title = "IAP Brand"
  project           = var.project_id
  
  depends_on = [google_project_service.apis]
}

resource "google_iap_client" "iap_client" {
  display_name = "iap-client"
  brand        = google_iap_brand.project_brand[0].name
}

#---------------------------------------------------------------
# Artifact Registry
#---------------------------------------------------------------

module "artifact_registry" {
  source        = "./modules/artifact-registry"
  location      = var.location
  description   = "nodeapp repository"
  repository_id = "nodeapp"
  shell_command = "bash ${path.cwd}/../src/artifact_push.sh ${data.google_project.project.project_id}"
}

#---------------------------------------------------------------
# Load Balancer Configuration
#---------------------------------------------------------------

# Backend service with IAP enabled
resource "google_compute_backend_service" "iap_backend_service" {
  name        = "iap-backend"
  project     = var.project_id
  protocol    = "HTTPS"
  timeout_sec = 30
  
  backend {
    group = google_compute_region_network_endpoint_group.cloudrun_neg.id
  }
  
  # Enable IAP here
  iap {
    enabled = true
    oauth2_client_id     = google_iap_client.iap_client.client_id
    oauth2_client_secret = google_iap_client.iap_client.secret
  }
}

# URL map
resource "google_compute_url_map" "iap_url_map" {
  name            = "iap-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.iap_backend_service.id
}

# SSL certificate for the domain
resource "google_compute_managed_ssl_certificate" "ssl_cert" {
  name    = "ssl-cert"
  project = var.project_id
  
  managed {
    domains = [var.domain_name]
  }
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.iap_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.ssl_cert.id]
}

# Global IP address
resource "google_compute_global_address" "lb_ip" {
  name    = "lb-ip"
  project = var.project_id
}

# Global forwarding rule
resource "google_compute_global_forwarding_rule" "https_forwarding" {
  name       = "https-forwarding"
  project    = var.project_id
  target     = google_compute_target_https_proxy.https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.lb_ip.pu
}

#---------------------------------------------------------------
# Cloud Run Service
#---------------------------------------------------------------

module "cloud_run_service_account" {
  source        = "./modules/service-account"
  account_id    = "cloud-run-sa"
  display_name  = "Cloud Run Service Account"
  project_id    = data.google_project.project.project_id
  member_prefix = "serviceAccount"
  permissions = [
    "roles/artifactregistry.reader"
  ]
}

# Network Endpoint Group for Cloud Run
resource "google_compute_region_network_endpoint_group" "cloudrun_neg" {
  name                  = "nodeapp-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.location
  project               = var.project_id

  cloud_run {
    service = module.cloud_run_service.name
  }
}

module "cloud_run_service" {
  source                           = "./modules/cloud-run"
  deletion_protection              = false
  ingress                          = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  service_account                  = module.cloud_run_service_account.sa_email
  location                         = var.location
  min_instance_count               = 2
  max_instance_count               = 5
  max_instance_request_concurrency = 80
  name                             = "nodeapp"
  volumes                          = []
  traffic = [
    {
      traffic_type         = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
      traffic_type_percent = 100
    }
  ]
  containers = [
    {
      port = 8080
      env = []
      volume_mounts     = []
      cpu_idle          = true
      startup_cpu_boost = true
      image             = "${var.location}-docker.pkg.dev/${data.google_project.project.project_id}/nodeapp/nodeapp:latest"
    }
  ]
  depends_on = [module.artifact_registry]
}

# Cloud Run IAM - Allow invoker access (IAP will handle auth)
resource "google_cloud_run_service_iam_binding" "invoker" {
  location = var.location
  project  = var.project_id
  service  = module.cloud_run_service.name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

# IAP access control
resource "google_iap_web_iam_binding" "iap_access" {
  project = var.project_id
  role    = "roles/iap.httpsResourceAccessor"
  members = var.allowed_iap_members
  depends_on = [google_compute_backend_service.iap_backend_service]
}