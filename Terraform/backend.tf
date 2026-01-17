terraform {
  required_version = ">= 1.6.0"

  backend "local" {
    # Ruta del archivo de estado local. Puede omitirse para usar el valor por defecto "terraform.tfstate".
    path = "terraform.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}
