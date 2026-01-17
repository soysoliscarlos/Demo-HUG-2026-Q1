provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
  # Extracción directa desde Vault
  client_id       = data.vault_kv_secret_v2.mi_spn.data["client_id"]
  client_secret   = data.vault_kv_secret_v2.mi_spn.data["client_secret"]
  tenant_id       = data.vault_kv_secret_v2.mi_spn.data["tenant_id"]
  subscription_id = data.vault_kv_secret_v2.mi_spn.data["subscription_id"]
}
