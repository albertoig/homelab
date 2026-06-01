resource "cloudflare_r2_bucket" "velero" {
  account_id = var.cloudflare_account_id
  name       = "${var.velero_bucket_name}-${var.environment}"
  location   = var.velero_bucket_location
}
