terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "~> 4.0"
    }
  }
}

provider "powerplatform" {
  # Configuration is provided via environment variables:
  #   POWER_PLATFORM_TENANT_ID
  #   POWER_PLATFORM_CLIENT_ID
  # For OIDC: POWER_PLATFORM_USE_OIDC=true
}