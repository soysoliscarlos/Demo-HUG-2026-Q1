resource "random_string" "prefix" {
  length  = 2
  special = false
  upper   = false
  numeric = false
  lower   = true
}

# #############################################
# Random Password for VM
# #############################################

resource "random_password" "vm_admin_password" {
  length  = 20
  special = true
  upper   = true
  lower   = true
  numeric = true

  # Caracteres especiales permitidos para contraseñas de Windows
  override_special = "!@#$%&*()-_=+[]{}<>:?"
}
