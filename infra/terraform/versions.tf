terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  # Backend local por defecto. Para equipo: descomentar azurerm backend.
  # backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
