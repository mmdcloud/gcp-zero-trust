#---------------------------------------------------------------
# Getting project information
#---------------------------------------------------------------
data "google_project" "project" {}

#---------------------------------------------------------------
# Enable Required APIs
#---------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset(var.apis_to_enable)

  disable_on_destroy = false
  project            = var.project_id
  service            = each.key
}

#---------------------------------------------------------------
# VPC Configuration
#---------------------------------------------------------------
module "vpc" {
  source                          = "git::https://github.com/mmdcloud/terraform-gcp-modules.git//vpc?ref=main"
  vpc_name                        = var.vpc_name
  delete_default_routes_on_create = var.delete_default_routes_on_create
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"

  subnets = [
    {
      name                     = var.subnet_name
      region                   = var.location
      purpose                  = "PRIVATE"
      role                     = "ACTIVE"
      private_ip_google_access = var.private_ip_google_access
      ip_cidr_range            = var.subnet_cidr
    }
  ]

  firewall_data = [
    {
      name          = var.firewall_name
      source_ranges = var.firewall_source_ranges
      allow_list    = var.firewall_allowed_ports
    },
  ]

  depends_on = [google_project_service.apis]
}

#---------------------------------------------------------------
# Artifact Registry
#---------------------------------------------------------------
module "artifact_registry" {
  source        = "git::https://github.com/mmdcloud/terraform-gcp-modules.git//artifact-registry?ref=main"
  project_id    = var.project_id
  location      = var.location
  artifact_type = var.artifact_type
  description   = var.artifact_repository_description
  repository_id = var.artifact_repository_id

  depends_on = [google_project_service.apis]
}

resource "null_resource" "build_and_push_image" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "bash ${path.cwd}/${var.run_image_push_script} ${data.google_project.project.project_id}"
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
  account_id    = var.cloud_run_sa_account_id
  display_name  = var.cloud_run_sa_display_name
  project_id    = data.google_project.project.project_id
  member_prefix = "serviceAccount"
  permissions   = var.cloud_run_sa_permissions
}

module "service_neg" {
  source     = "git::https://github.com/mmdcloud/terraform-gcp-modules.git//network_endpoint_groups/serverless_neg?ref=main"
  project_id = var.project_id
  neg_name   = var.neg_name
  region     = var.location
  cloud_run = {
    service = module.cloud_run_service.service_name
  }
}

module "cloud_run_service" {
  source                           = "git::https://github.com/mmdcloud/terraform-gcp-modules.git//cloud-run?ref=main"
  project_id                       = var.project_id
  type                             = "SERVICE"
  deletion_protection              = var.cloud_run_deletion_protection
  ingress                          = var.cloud_run_ingress
  service_account                  = module.cloud_run_service_account.sa_email
  location                         = var.location
  min_instance_count               = var.cloud_run_min_instance_count
  max_instance_count               = var.cloud_run_max_instance_count
  max_instance_request_concurrency = var.cloud_run_max_instance_request_concurrency
  name                             = var.cloud_run_service_name
  volumes                          = []

  traffic = [
    {
      traffic_type         = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
      traffic_type_percent = 100
    }
  ]

  containers = [
    {
      port              = var.cloud_run_container_port
      env               = var.cloud_run_env
      volume_mounts     = []
      cpu_idle          = var.cloud_run_cpu_idle
      startup_cpu_boost = var.cloud_run_startup_cpu_boost
      image             = "${var.location}-docker.pkg.dev/${data.google_project.project.project_id}/${var.artifact_repository_id}/${var.cloud_run_service_name}:${var.cloud_run_image_tag}"
    }
  ]

  depends_on = [null_resource.build_and_push_image]
}

resource "google_cloud_run_v2_service_iam_member" "cloud_run_access" {
  for_each = toset(var.cloud_run_invoker_members)
  name     = module.cloud_run_service.service_name
  location = var.location
  project  = var.project_id
  role     = "roles/run.invoker"
  member   = each.key
}

#---------------------------------------------------------------
# Load Balancer Configuration
#---------------------------------------------------------------
module "lb" {
  source                   = "git::https://github.com/mmdcloud/terraform-gcp-modules.git//load-balancer?ref=main"
  project_id               = var.project_id
  name                     = var.lb_name
  load_balancer_type       = var.lb_type
  region                   = var.location
  create_proxy_only_subnet = var.create_proxy_only_subnet
  create_static_ip         = var.create_static_ip

  backends = {
    lb = {
      is_default        = true
      protocol          = "HTTP"
      port_name         = var.lb_backend_port_name
      is_serverless_neg = true
      iap_config = [
        {
          enabled = var.iap_enabled
        }
      ]
      manage_health_check = var.lb_manage_health_check
      groups = [
        { group = module.service_neg.id }
      ]
    }
  }

  domains                 = var.domains
  enable_ssl              = var.enable_ssl
  enable_http             = var.enable_http
  managed_ssl_certificate = var.managed_ssl_certificate
  https_redirect          = var.https_redirect
  enable_cloud_armor      = var.enable_cloud_armor

  depends_on = [module.cloud_run_service]
}

# IAP access control
resource "google_iap_web_backend_service_iam_member" "iap_access" {
  for_each            = toset(var.allowed_iap_members)
  project             = var.project_id
  role                = "roles/iap.httpsResourceAccessor"
  member              = each.key
  web_backend_service = module.lb.backend_service_names["lb"]
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
#
#   basic {
#     conditions {
#       ip_subnetworks = var.trusted_ip_ranges   # e.g. corporate egress IPs / office CIDRs
#       # required_access_levels = []            # chain other access levels if needed
#       # members = []                            # optionally scope to specific identities here too
#     }
#   }
# }
#
# # IAP access control, now conditioned on the access level
# resource "google_iap_web_backend_service_iam_binding" "iap_access" {
#   project             = var.project_id
#   role                = "roles/iap.httpsResourceAccessor"
#   members             = var.allowed_iap_members
#   web_backend_service = module.lb.backend_service_names["lb"]
#
#   condition {
#     title       = "require-trusted-access-level"
#     description = "Only allow IAP access from the trusted access level"
#     expression  = "\"${google_access_context_manager_access_level.trusted_access.name}\" in request.auth.access_levels"
#   }
#
#   depends_on = [module.lb, google_access_context_manager_access_level.trusted_access]
# }
