variable "cloudflare_account_id" {
  description = "Cloudflare account ID (visible in the dashboard URL or Overview page)"
  type        = string
}

variable "environment" {
  description = "Deployment environment. Appended to all R2 bucket names (e.g. homelab-velero-dev)."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "velero_bucket_name" {
  description = "Base name for the Velero R2 bucket. Environment is appended automatically: <name>-<env>."
  type        = string
  default     = "homelab-velero"
}

variable "velero_bucket_location" {
  description = "R2 bucket location hint (WEUR, EEUR, APAC, WNAM, ENAM)"
  type        = string
  default     = "WEUR"
}
