provider "vault" {
  address = "http://127.0.0.1:8200"
}

data "vault_kv_secret_v2" "mi_spn" {
  mount = "kv"
  name  = "spn/terraform-servicePrincipal"
}
