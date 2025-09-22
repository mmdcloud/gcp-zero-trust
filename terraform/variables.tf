variable "location" {
  type    = string
  default = "us-central1"
}

variable "project_id" {
  type    = string
  default = "encoded-alpha-457108-e8"
}

variable "allowed_iap_members" {
  type    = list(string)
  default = ["user:admin@mohitcloud.xyz"]
}

variable "domain_name" {
  type    = string
  default = "mohitcloud.xyz"
}