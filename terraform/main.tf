#---------------------------------------------------------------
# Getting project information
#---------------------------------------------------------------
data "google_project" "project" {}

#---------------------------------------------------------------
# Enable Required APIs
#---------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "run.googleapis.com",
    "iap.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com"
  ])
  disable_on_destroy = false
  project            = var.project_id
  service            = each.key
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
# Artifact Registry
#---------------------------------------------------------------
module "artifact_registry" {
  source        = "./modules/artifact-registry"
  project_id    = var.project_id
  location      = var.location
  artifact_type = "DOCKER"
  description   = "nodeapp repository"
  repository_id = "nodeapp"
}

resource "null_resource" "build_and_push_image" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = "bash ${path.cwd}/../src/artifact_push.sh ${data.google_project.project.project_id}"
  }

  depends_on = [
    module.artifact_registry
  ]
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

module "service_neg" {
  source       = "./modules/network_endpoint_groups"
  neg_name     = "service-neg"
  neg_type     = "SERVERLESS"
  location     = var.location
  service_name = module.cloud_run_service.name
}

module "cloud_run_service" {
  source                           = "./modules/cloud-run"
  project_id                       = var.project_id
  type                             = "SERVICE"
  deletion_protection              = false
  ingress                          = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
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
      port              = 8080
      env               = []
      volume_mounts     = []
      cpu_idle          = true
      startup_cpu_boost = true
      image             = "${var.location}-docker.pkg.dev/${data.google_project.project.project_id}/nodeapp/nodeapp:latest"
    }
  ]
  depends_on = [null_resource.build_and_push_image]
}

resource "google_cloud_run_service_iam_member" "cloud_run_access" {
  location = var.location
  project  = var.project_id
  service  = module.cloud_run_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

#---------------------------------------------------------------
# Load Balancer Configuration
#---------------------------------------------------------------
module "lb" {
  source                   = "./modules/lb"
  project_id               = var.project_id
  name                     = "lb"
  load_balancer_type       = "EXTERNAL"
  region                   = var.location
  create_proxy_only_subnet = false
  create_static_ip         = true
  backends = {
    lb = {
      is_default        = true
      protocol          = "HTTP"
      port_name         = "http"
      is_serverless_neg = true
      iap_config = [
        {
          enabled = true
        }
      ]
      manage_health_check = false
      groups = [
        { group = module.service_neg.id }
      ]
    }
  }
  domains                 = ["mohitd.xyz"]
  enable_ssl              = true
  enable_http             = true
  managed_ssl_certificate = true
  https_redirect          = true
  enable_cloud_armor      = false
  depends_on              = [module.cloud_run_service]
}

# IAP access control
resource "google_iap_web_backend_service_iam_binding" "iap_access" {
  project             = var.project_id
  role                = "roles/iap.httpsResourceAccessor"
  members             = var.allowed_iap_members
  web_backend_service = module.lb.backend_service_names["lb"] # was backend_service_self_links — must be .name
  depends_on          = [module.lb]
}

# #---------------------------------------------------------------
# # Access Context Manager
# #---------------------------------------------------------------
# # The org-level access policy is typically a singleton per org and
# # already exists — look it up rather than creating a second one.
# data "google_access_context_manager_access_policy" "policy" {
#   # If you don't already have one, create it instead with:
#   # resource "google_access_context_manager_access_policy" "policy" {
#   #   parent = "organizations/${var.org_id}"
#   #   title  = "default-policy"
#   # }
#   name = var.access_context_manager_policy_name  # e.g. "accessPolicies/123456789"
# }

# resource "google_access_context_manager_access_level" "trusted_access" {
#   parent = data.google_access_context_manager_access_policy.policy.name
#   name   = "${data.google_access_context_manager_access_policy.policy.name}/accessLevels/trusted_nodeapp_access"
#   title  = "trusted_nodeapp_access"

#   basic {
#     conditions {
#       ip_subnetworks = var.trusted_ip_ranges   # e.g. corporate egress IPs / office CIDRs
#       # required_access_levels = []            # chain other access levels if needed
#       # members = []                            # optionally scope to specific identities here too
#     }
#   }
# }

# # IAP access control, now conditioned on the access level
# resource "google_iap_web_backend_service_iam_binding" "iap_access" {
#   project             = var.project_id
#   role                = "roles/iap.httpsResourceAccessor"
#   members             = var.allowed_iap_members
#   web_backend_service = module.lb.backend_service_names["lb"]

#   condition {
#     title       = "require-trusted-access-level"
#     description = "Only allow IAP access from the trusted access level"
#     expression  = "\"${google_access_context_manager_access_level.trusted_access.name}\" in request.auth.access_levels"
#   }

#   depends_on = [module.lb, google_access_context_manager_access_level.trusted_access]
# }
