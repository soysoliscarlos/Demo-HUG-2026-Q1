# Demo: Infra privada de Azure + OPA + Vault

Este repo contiene tres piezas integradas para montar un entorno seguro en Azure con red privada y control de seguridad:

- `Terraform/`: Infraestructura en Azure (VNet, subnets, NSG, Private Endpoints, DNS privado, Storage, Key Vault) con acceso privado.
- `OPA/`: Política Rego que prohíbe exposición a Internet (public network access) y script para evaluar un plan de Terraform.
- `Vault/`: Configuración local de HashiCorp Vault para gestionar credenciales de Azure que Terraform consume sin exponer secretos en archivos.

A continuación verás cómo está armado, cómo ejecutarlo en Windows (PowerShell) y cómo validar que nada quede con acceso público.

## Arquitectura resumida

- Red
  - VNet principal con subnets para apps, datos y una subnet dedicada a Private Endpoints
  - Peering con una VNet existente `Vnet-Jumpbox` (RG `RG-VM-Jumpbox`)
  - NSGs por subnet
  - Private Endpoints para: Storage (Blob/File) y Key Vault
  - Private DNS Zones enlazadas a la VNet local y a la VNet remota (peering)
- Servicios de datos y secretos
  - Storage Account (acceso público deshabilitado)
  - Key Vault (RBAC enabled, acceso público deshabilitado)

## Terraform

Ubicación: `Terraform/`

### Proveedores y autenticación

- Proveedores usados: `azurerm`, `vault`, `random` (ver `backend.tf` y `providers.tf`).
- Terraform obtiene credenciales de Azure desde Vault leyendo `kv/spn/terraform-servicePrincipal` (ver `vault.tf`). Claves esperadas:
  - `tenant_id`, `subscription_id`, `client_id`, `client_secret`
- El proveedor `vault` se conecta a `http://127.0.0.1:8200` y usa `var.vault_token`.

### Recursos principales (archivos .tf)

- `resource_group.tf`: Resource Group
- `vnet.tf`: VNet, subnets, NSGs y asociaciones
- `private_endpoints.tf`: Private Endpoints + Private DNS Zones y VNet Links (local y remota)
- `storage.tf`: Storage Account + Container (acceso público deshabilitado)
- `key_vault.tf`: Key Vault (RBAC, acceso público deshabilitado)
- `peering.tf`: Peering entre la VNet local y `Vnet-Jumpbox`
- `outputs.tf`: Salidas útiles (ids, nombres, DNS zones, etc.)
- `variables.tf` y `locals.tf`: variables de entrada y etiquetas comunes
- `backend.tf`: backend local por defecto
- `vault.tf`: Configuración del proveedor Vault y data source para credenciales
- `data.tf`: Data sources (configuración del cliente Azure y VNet remota)
- `random.tf`: Generación de prefijo aleatorio para nombres de recursos
- `main.tf`: Archivo de referencia (recursos organizados en archivos individuales)

### Variables clave (extracto)

- Despliegue y tagging: `environment`, `tags`
- RG y región: `resource_group_name`, `location`
- Red: `vnet_name`, `vnet_address_space`, `subnets` (mapa con name/prefixes/optional delegation)
- Storage: `storage_account_name`, `container_name`, `container_access_type`
- Key Vault: `key_vault_name`, `key_vault_sku`
- Vault: `vault_token` (sensible, se pasa como variable de entorno)

Revisa `Terraform/terraform.tfvars.example` para un ejemplo de valores. Nota: las credenciales de Azure no van en `.tfvars`, van en Vault.

### Flujo de ejecución

1. Levanta Vault y carga credenciales (ver sección Vault)

2. Exporta el token de Vault para Terraform

   ```powershell
   $env:TF_VAR_vault_token = "<TOKEN_VAULT>"
   ```

3. Inicializa, planifica y aplica

   ```powershell
   cd ./Terraform
   terraform init
   terraform plan -out tfplan.bin
   terraform apply tfplan.bin
   ```

4. (Opcional) Genera/actualiza el plan en JSON para OPA

   ```powershell
   terraform show -json tfplan.bin > tfplan.json
   ```

## OPA (Open Policy Agent)

Ubicación: `OPA/`

- Política: `deny_public_internet.rego` (paquete `terraform.deny_public_internet`)
  - Revisa recursos del plan (`tfplan/v2`) y emite violaciones si encuentra:
    - `public_network_access != "Disabled"` o `public_network_access_enabled = true`
    - `allow_blob_public_access = true` en Storage
    - NSGs con reglas outbound `Allow` hacia `Internet`/`0.0.0.0/0`
- Script helper: `evaluar_politica.ps1` ejecuta `opa eval` y muestra los resultados con formato coloreado.

### Cómo evaluar el plan con OPA

Asegúrate de tener `plan.json` generado desde `Terraform/`:

```powershell
cd ./Terraform
terraform plan -out tfplan.bin
terraform show -json tfplan.bin > tfplan.json
```

Luego ejecuta el script de evaluación:

```powershell
cd ./OPA
.\evaluar_politica.ps1
```

O con parámetros personalizados:

```powershell
.\evaluar_politica.ps1 -PlanFile "..\Terraform\tfplan.json" -PolicyFile "deny_public_internet.rego"
```

Para usar en CI/CD (falla si hay violaciones):

```powershell
.\evaluar_politica.ps1 -FailOnViolation
```

- Salida vacía: no hay violaciones
- Salida con violaciones: revisa y corrige flags de acceso público

Para más detalles, consulta [`OPA/README_EVALUACION.md`](OPA/README_EVALUACION.md).

## Vault (HashiCorp)

Ubicación: `Vault/`

HashiCorp Vault se utiliza para almacenar de forma segura las credenciales de Azure que consume Terraform, evitando exponer secretos en archivos de configuración.

**📚 Documentación detallada**: Consulta [`Vault/README.md`](Vault/README.md) para documentación completa sobre:

- Configuración detallada de archivos de ejemplo (`vault.hcl.example`, `init.txt`)
- Proceso paso a paso de configuración inicial
- Operaciones diarias (iniciar, desbloquear, leer secretos)
- Mejores prácticas de seguridad
- Solución de problemas

### Resumen de Componentes

- **Configuración**: `config/vault.hcl` (almacenamiento en filesystem, listener TCP sin TLS, UI habilitada)
  - Archivo de ejemplo: `config/vault.hcl.example` con documentación detallada de cada parámetro
- **Estado de datos**: Las carpetas `core/`, `logical/`, `sys/`, `data/` contienen el data dir de Vault (no publiques estos secretos)
- **Archivo `init.txt`**: Contiene llaves de unseal y un root token de ejemplo **PARA DEMO**. No uses esto en producción.

### Proceso de Configuración Inicial

#### Paso 1: Preparar Configuración

```powershell
cd ./Vault
# Si no existe, copia el ejemplo
if (-not (Test-Path .\config\vault.hcl)) {
    Copy-Item .\config\vault.hcl.example .\config\vault.hcl
}
# Ajusta la ruta en vault.hcl según tu entorno
```

#### Paso 2: Inicializar Vault (Primera Vez)

1. **Inicia el servidor de Vault** en una terminal:

   ```powershell
   vault server -config .\config\vault.hcl
   ```

2. **En otra terminal, inicializa Vault**:

   ```powershell
   $env:VAULT_ADDR = "http://127.0.0.1:8200"
   vault operator init
   ```

   **⚠️ IMPORTANTE**: Guarda las 5 Unseal Keys y el Initial Root Token en un lugar seguro. Sin estas credenciales, no podrás acceder a Vault.

#### Paso 3: Desbloquear (Unseal) Vault

```powershell
$env:VAULT_ADDR = "http://127.0.0.1:8200"
vault operator unseal <UNSEAL_KEY_1>
vault operator unseal <UNSEAL_KEY_2>
vault operator unseal <UNSEAL_KEY_3>
```

#### Paso 4: Autenticarse y Configurar

```powershell
# Autentícate con el root token
vault login <ROOT_TOKEN>

# Habilita el secrets engine KV v2
vault secrets enable -path=kv kv-v2

# Almacena credenciales de Azure
vault kv put kv/spn/terraform-servicePrincipal `
  tenant_id="<TU_TENANT_ID>" `
  subscription_id="<TU_SUBSCRIPTION_ID>" `
  client_id="<TU_CLIENT_ID>" `
  client_secret="<TU_CLIENT_SECRET>"
```

#### Paso 5: Crear Token para Terraform (Recomendado)

```powershell
# Crea una política con permisos limitados
vault policy write terraform-policy - <<EOF
path "kv/data/spn/terraform-servicePrincipal" {
  capabilities = ["read"]
}

path "kv/metadata/spn/terraform-servicePrincipal" {
  capabilities = ["read", "list"]
}
EOF

# Crea un token con esta política
vault token create -policy=terraform-policy -ttl=24h
```

#### Paso 6: Exportar Token para Terraform

```powershell
# Usa el token generado (NO el root token)
$env:TF_VAR_vault_token = "<TOKEN_GENERADO_EN_PASO_5>"
```

### Operaciones Diarias

**Iniciar Vault**:

```powershell
cd ./Vault
vault server -config .\config\vault.hcl
```

**Desbloquear Vault** (después de reiniciar):

```powershell
$env:VAULT_ADDR = "http://127.0.0.1:8200"
vault operator unseal <UNSEAL_KEY_1>
vault operator unseal <UNSEAL_KEY_2>
vault operator unseal <UNSEAL_KEY_3>
```

**Verificar estado**:

```powershell
vault status
```

**Leer credenciales**:

```powershell
vault kv get kv/spn/terraform-servicePrincipal
```

### Seguridad

- ⚠️ **Rotar y no commitear tokens/keys**. El `init.txt` es solo demostrativo.
- ⚠️ **Usa TLS y políticas en Vault para cualquier uso real**.
- ✅ **Crea tokens con permisos limitados** en lugar de usar el root token.
- ✅ **En producción**: Configura TLS, auto-unseal (Azure Key Vault), y backend remoto (Azure Storage).

Para más detalles, consulta la [documentación completa de Vault](Vault/README.md).

## Solución de problemas

- Autenticación Azure: "The subscription is not registered" o 401
  - Verifica que Vault esté arriba y `kv/spn/terraform-servicePrincipal` tenga `tenant_id`, `subscription_id`, `client_id`, `client_secret`
  - Asegúrate de exportar `TF_VAR_vault_token`
  - Verifica que el Service Principal tenga los permisos necesarios en Azure
- OPA falla con violaciones
  - Corrige flags: en Storage deshabilita `allow_blob_public_access` y `public_network_access_enabled`
  - En Key Vault, ajusta `public_network_access_enabled = false`
  - Revisa NSGs para reglas outbound que permitan tráfico a Internet
- DNS/Resolución privada
  - Revisa los `private_dns_zone_virtual_network_link` para la VNet local y la VNet remota (`Vnet-Jumpbox`)
  - Verifica que la VNet remota exista en el Resource Group `RG-VM-Jumpbox`
- Permisos
  - El principal usado debe tener permisos suficientes (Owner/Contributor) para crear todos los recursos
  - Para el peering bidireccional, necesitas permisos en ambas VNets

## Referencias rápidas

- **Documentación detallada del proyecto**:
  - `Terraform/README.md` - Documentación completa de la infraestructura
  - `Vault/README.md` - Documentación detallada de configuración y uso de Vault
  - `OPA/README_EVALUACION.md` - Documentación de políticas OPA
- **Documentación oficial**:
  - Proveedores Terraform: azurerm, vault, random
  - OPA (tfplan/v2): <https://www.openpolicyagent.org/>
  - Vault: <https://developer.hashicorp.com/vault>

---

Hecho para HashiTalk España 2026. Ajusta nombres/regiones según tu suscripción.
