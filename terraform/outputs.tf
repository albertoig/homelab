output "velero_bucket_name" {
  description = "Set as velero.bucket in helmfile/environments/<env>/config.yaml"
  value       = cloudflare_r2_bucket.velero.name
}

output "velero_s3_endpoint" {
  description = "Set as velero.s3Url in helmfile/environments/<env>/config.yaml"
  value       = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
}

output "next_step" {
  description = "Next step after applying"
  value       = "Go to Cloudflare Dashboard → R2 → Manage R2 API Tokens → Create Token (Object Read & Write on bucket: ${cloudflare_r2_bucket.velero.name}). Add the Access Key ID and Secret Access Key to the Velero SOPS secret for the ${var.environment} environment."
}
