terraform {
  required_version = ">= 1.6.0"
  required_providers {
    # TODO: Ensure all required providers are listed here.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.71.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
    modtm = {
      source = "azure/modtm"
      version = "~> 0.3"
    }
  }
}
