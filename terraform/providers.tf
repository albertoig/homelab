terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "homelab-terraform-state"
    key    = "terraform.tfstate"
    region = "auto"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true

    # endpoint, access_key, and secret_key are injected via -backend-config flags
    # in the mise tasks. Set CLOUDFLARE_R2_ENDPOINT, CLOUDFLARE_R2_ACCESS_KEY_ID,
    # and CLOUDFLARE_R2_SECRET_ACCESS_KEY in .mise.local.toml.
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  # Reads CLOUDFLARE_API_TOKEN from environment.
  # The token needs Account > R2 Storage > Edit permission.
}
