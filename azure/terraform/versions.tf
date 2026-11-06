terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # Version verificada durante la validacion con Azure for Students.
      version = "= 4.40.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
