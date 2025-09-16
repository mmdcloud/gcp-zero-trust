resource "google_project_service" "enabled" {
  for_each = toset([
    "run.googleapis.com",
    "iap.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com"
  ])
  project = var.project_id
  service = each.key
}

#---------------------------------------------------------------
# VPC Configuration
#---------------------------------------------------------------

# VPC
module "vpc" {
  source                  = "../modules/network/vpc"
  auto_create_subnetworks = false
  vpc_name                = "vpc"
}

# Subnet
module "vpc_subnet" {
  source                   = "../modules/network/subnet"
  name                     = "vpc-subnet"
  subnets                  = ["10.1.0.0/24"]
  vpc_id                   = module.vpc.vpc_id
  private_ip_google_access = true
  location                 = var.location
}

#---------------------------------------------------------------
# Artifact Registry
#---------------------------------------------------------------
module "artifact_registry" {
  source        = "../modules/artifact-registry"
  location      = var.location
  description   = "cloud run code repository"
  repository_id = "cloud-run-repo"
  shell_command = "bash ${path.cwd}/../../src/artifact_push.sh"
}

#---------------------------------------------------------------
# Cloud Run Service
#---------------------------------------------------------------
module "cloud_run_service" {
  source                           = "../modules/cloud-run"
  deletion_protection              = false
  ingress                          = "INGRESS_TRAFFIC_ALL"
  vpc_connector_name               = module.carshub_vpc_connectors.vpc_connectors[0].id
  service_account                  = module.carshub_cloud_run_service_account.sa_email
  location                         = var.location
  min_instance_count               = 2
  max_instance_count               = 5
  max_instance_request_concurrency = 80
  name                             = "carshub-frontend-service"
  volumes                          = []
  traffic = [
    {
      traffic_type         = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
      traffic_type_percent = 100
    }
  ]
  containers = [
    {
      env               = []
      volume_mounts     = []
      cpu_idle          = true
      startup_cpu_boost = true
      image             = "${var.location}-docker.pkg.dev/${data.google_project.project.project_id}/carshub-frontend/carshub-frontend:latest"
    }
  ]
  depends_on = [module.artifact_registry]
}

resource "google_service_account" "run_sa" {
  account_id   = "cr-run-sa"
  display_name = "Cloud Run runtime SA"
}

resource "google_project_iam_member" "runtime_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${local.runtime_sa_email}"
}

resource "google_iap_brand" "brand" {
  count = var.iap_brand_create ? 1 : 0


  project           = var.project_id
  application_title = "IAP Brand for ${var.service_name}"
  support_email     = "support@${var.project_id}.iam.gserviceaccount.com"
}


resource "google_iap_client" "client" {
  count        = var.iap_brand_create ? 1 : 0
  brand        = google_iap_brand.brand[0].name
  display_name = "iap-client-${var.service_name}"
}

# Grant IAP access to the Cloud Run service for allowed members
resource "google_iap_web_cloud_run_service_iam_member" "iap_access" {
  for_each          = toset(var.allowed_iap_members)
  project           = var.project_id
  region            = var.region
  cloud_run_service = google_cloud_run_service.app.name
  role              = "roles/iap.httpsResourceAccessor"
  member            = each.key
}
