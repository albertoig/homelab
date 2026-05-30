variable "cloudflare_account_id" {
  description = "Cloudflare account ID (visible in the dashboard URL or Overview page)"
  type        = string
}

variable "velero_bucket_name" {
  description = "R2 bucket name for Velero backups"
  type        = string
  default     = "homelab-velero"
}

variable "velero_bucket_location" {
  description = "R2 bucket location hint (WEUR, EEUR, APAC, WNAM, ENAM)"
  type        = string
  default     = "WEUR"
}
