# Infraestructura Terraform - HashiTalk España 2026

Este proyecto de Terraform despliega una infraestructura segura en Azure con red privada, endpoints privados y recursos para cargas de trabajo RAG (Retrieval-Augmented Generation).

## 📋 Tabla de Contenidos

- [Descripción General](#descripción-general)
- [Arquitectura](#arquitectura)
- [Archivos de Configuración](#archivos-de-configuración)
- [Recursos Desplegados](#recursos-desplegados)
- [Prerrequisitos](#prerrequisitos)
- [Configuración](#configuración)
- [Uso](#uso)
- [Variables](#variables)
- [Outputs](#outputs)
- [Referencias](#referencias)

## 🎯 Descripción General

Esta configuración de Terraform crea una infraestructura de Azure con las siguientes características principales:

- **Red Virtual (VNet)** con subredes dedicadas y grupos de seguridad de red (NSG)
- **Storage Account** con acceso privado y endpoints privados para Blob y File
- **Key Vault** con RBAC habilitado y acceso privado
- **Private Endpoints** para todos los servicios críticos
- **Private DNS Zones** para resolución DNS privada
- **VNet Peering** con una VNet existente para conectividad híbrida
- **Autenticación mediante HashiCorp Vault** para credenciales de Azure

## 🏗️ Arquitectura

### Características de Red Privada

La infraestructura implementa una arquitectura de red segura con las siguientes características:

#### Virtual Network (VNet)
- **VNet principal** con espacio de direcciones configurable (por defecto: `10.0.0.0/16`)
- **Subredes dedicadas**:
  - `subnet-app`: Para aplicaciones (10.0.1.0/24) con service endpoints para Storage y Key Vault
  - `subnet-data`: Para datos (10.0.2.0/24) con service endpoints para Storage y SQL
  - `subnet-ai`: Para servicios de IA (10.0.3.0/24) con service endpoints para Cognitive Services
  - `subnet-private-endpoints`: Para endpoints privados (10.0.4.0/24)

#### Private Endpoints
Se crean private endpoints para todos los recursos críticos:
- **Storage Account**: Blob y File endpoints
- **Key Vault**: Acceso seguro a secretos

#### Private DNS Zones
Zonas DNS privadas con vnet links automáticos:
- `privatelink.blob.core.windows.net` - Storage Blobs
- `privatelink.file.core.windows.net` - Storage Files
- `privatelink.vaultcore.azure.net` - Key Vault

Los vnet links se crean tanto para la VNet local como para la VNet remota (Vnet-Jumpbox).

#### Seguridad de Red
- **Acceso público deshabilitado** en Storage Account y Key Vault
- **NSGs** asociados a cada subnet
- **Service Endpoints** configurados para servicios críticos
- **VNet Peering** bidireccional con VNet existente

## 📁 Archivos de Configuración

### `backend.tf`
Configura el backend de Terraform y los proveedores requeridos.

**Características:**
- Backend local (archivo `terraform.tfstate`)
- Requiere Terraform >= 1.6.0
- Proveedores configurados:
  - `azurerm` (~> 4.0): Proveedor de Azure Resource Manager
  - `random` (~> 3.7): Generación de valores aleatorios
  - `vault` (~> 4.0): Integración con HashiCorp Vault

**Bloques principales:**
- `terraform`: Configuración del backend y versiones requeridas
- `required_providers`: Definición de proveedores con versiones

### `providers.tf`
Configura el proveedor de Azure con autenticación mediante HashiCorp Vault.

**Características:**
- Extracción de credenciales desde Vault usando `data.vault_kv_secret_v2.mi_spn`
- Configuración de features para Key Vault (purge on destroy)
- Credenciales obtenidas desde el path `kv/spn/terraform-servicePrincipal` en Vault

**Configuración:**
- `client_id`: ID del Service Principal
- `client_secret`: Secret del Service Principal
- `tenant_id`: ID del tenant de Azure AD
- `subscription_id`: ID de la suscripción de Azure

### `vault.tf`
Configura el proveedor de HashiCorp Vault y obtiene las credenciales de Azure.

**Características:**
- Conexión a Vault local en `http://127.0.0.1:8200`
- Data source para obtener secretos del Service Principal desde KV v2 engine
- Path del secreto: `kv/spn/terraform-servicePrincipal`

**Recursos:**
- `provider "vault"`: Configuración del proveedor Vault
- `data "vault_kv_secret_v2"`: Obtención de credenciales

### `variables.tf`
Define todas las variables de entrada para la configuración.

**Categorías de variables:**

1. **Configuración General:**
   - `environment`: Identificador del entorno (dev, staging, prod)
   - `tags`: Etiquetas adicionales para recursos

2. **Resource Group:**
   - `resource_group_name`: Nombre del grupo de recursos
   - `location`: Región de Azure (default: "eastus")

3. **Virtual Network:**
   - `vnet_name`: Nombre de la VNet
   - `vnet_address_space`: Espacio de direcciones (default: ["10.0.0.0/16"])
   - `subnets`: Mapa de subredes con configuración detallada

4. **Storage Account:**
   - `storage_account_name`: Nombre de la cuenta de almacenamiento
   - `container_name`: Nombre del contenedor
   - `container_access_type`: Tipo de acceso (private, blob, container)

5. **Key Vault:**
   - `key_vault_name`: Nombre del Key Vault
   - `key_vault_sku`: SKU (standard o premium)

### `locals.tf`
Define valores locales reutilizables en toda la configuración.

**Características:**
- `etiquetas_comunes`: Merge de etiquetas comunes con etiquetas personalizadas
- Incluye automáticamente:
  - `environment`: Del valor de la variable
  - `workload`: Siempre "rag"
  - Etiquetas adicionales de `var.tags`

### `random.tf`
Genera un prefijo aleatorio para nombres de recursos.

**Características:**
- Genera un string de 3 caracteres en minúsculas
- Sin caracteres especiales ni números
- Se usa como prefijo para evitar conflictos de nombres en Azure

**Uso:**
- Storage Account: `${random_string.prefix.result}${var.storage_account_name}`
- Key Vault: `${random_string.prefix.result}-${var.key_vault_name}`
- Resource Group: `${random_string.prefix.result}-${var.resource_group_name}`

### `data.tf`
Define data sources para obtener información de recursos existentes.

**Data Sources:**
- `azurerm_client_config.current`: Configuración del cliente actual (tenant_id, object_id, etc.)
- `azurerm_virtual_network.vnet-vm`: VNet existente "Vnet-Jumpbox" en "RG-VM-Jumpbox"

**Uso:**
- `azurerm_client_config`: Para tenant_id en Key Vault y object_id para role assignments
- `azurerm_virtual_network.vnet-vm`: Para VNet peering y vnet links en Private DNS Zones

### `resource_group.tf`
Crea el grupo de recursos de Azure.

**Recurso:**
- `azurerm_resource_group.rag`: Grupo de recursos principal
  - Nombre: `${random_string.prefix.result}-${var.resource_group_name}`
  - Ubicación: `var.location`
  - Tags: `local.etiquetas_comunes`

### `vnet.tf`
Crea la red virtual, subredes y grupos de seguridad de red.

**Recursos:**

1. **Virtual Network:**
   - `azurerm_virtual_network.vnet`: VNet principal con espacio de direcciones configurable

2. **Subnets:**
   - `azurerm_subnet.subnet`: Crea subredes dinámicamente usando `for_each = var.subnets`
   - Soporta service endpoints opcionales
   - Soporta delegación de subred opcional

3. **Network Security Groups:**
   - `azurerm_network_security_group.nsg`: NSG para cada subred
   - `azurerm_subnet_network_security_group_association.nsg_association`: Asociación NSG-Subnet

**Características:**
- Subredes creadas dinámicamente desde la variable `subnets`
- Cada subred puede tener service endpoints y delegación configurados
- NSG automático para cada subred

### `storage.tf`
Crea la cuenta de almacenamiento y el contenedor.

**Recursos:**

1. **Storage Account:**
   - `azurerm_storage_account.rag`: Cuenta de almacenamiento
     - Tier: Standard
     - Replication: LRS (Locally Redundant Storage)
     - **Acceso público deshabilitado** (`public_network_access_enabled = false`)
     - Nombre con prefijo aleatorio

2. **Storage Container:**
   - `azurerm_storage_container.rag`: Contenedor dentro de la cuenta
     - Tipo de acceso configurable (private, blob, container)

### `key_vault.tf`
Crea el Key Vault con RBAC habilitado.

**Recursos:**

1. **Key Vault:**
   - `azurerm_key_vault.rag`: Key Vault principal
     - SKU configurable (standard o premium)
     - **RBAC habilitado** (`rbac_authorization_enabled = true`)
     - **Acceso público deshabilitado** (`public_network_access_enabled = false`)
     - Tenant ID desde `data.azurerm_client_config.current`

2. **Role Assignment:**
   - `azurerm_role_assignment.kv_admin`: Asigna rol "Key Vault Administrator" al usuario actual
     - Principal ID desde `data.azurerm_client_config.current.object_id`

### `private_endpoints.tf`
Crea los private endpoints y las Private DNS Zones.

**Recursos:**

1. **Private DNS Zones:**
   - `azurerm_private_dns_zone.blob`: `privatelink.blob.core.windows.net`
   - `azurerm_private_dns_zone.file`: `privatelink.file.core.windows.net`
   - `azurerm_private_dns_zone.keyvault`: `privatelink.vaultcore.azure.net`

2. **VNet Links (VNet Local):**
   - `azurerm_private_dns_zone_virtual_network_link.blob_link`
   - `azurerm_private_dns_zone_virtual_network_link.file_link`
   - `azurerm_private_dns_zone_virtual_network_link.keyvault_link`

3. **VNet Links (VNet Remota - Vnet-Jumpbox):**
   - `azurerm_private_dns_zone_virtual_network_link.blob_link_vm`
   - `azurerm_private_dns_zone_virtual_network_link.file_link_vm`
   - `azurerm_private_dns_zone_virtual_network_link.keyvault_link_vm`

4. **Private Endpoints:**
   - `azurerm_private_endpoint.storage_blob`: Endpoint para Storage Blob
   - `azurerm_private_endpoint.storage_file`: Endpoint para Storage File
   - `azurerm_private_endpoint.keyvault`: Endpoint para Key Vault

**Características:**
- Todos los endpoints se crean en `subnet-private-endpoints`
- Cada endpoint incluye un `private_dns_zone_group` para registro DNS automático
- VNet links creados para ambas VNets (local y remota)

### `peering.tf`
Configura el peering bidireccional entre VNets.

**Recursos:**

1. **Peering Local a Remota:**
   - `azurerm_virtual_network_peering.vnet_to_vnet_vm`: Desde VNet local a Vnet-Jumpbox
     - Permite acceso de red virtual
     - No permite tráfico reenviado
     - No permite gateway transit

2. **Peering Remota a Local:**
   - `azurerm_virtual_network_peering.vnet_vm_to_vnet`: Desde Vnet-Jumpbox a VNet local
     - Configuración simétrica al peering anterior

**Características:**
- Peering bidireccional para permitir comunicación en ambas direcciones
- Configuración de seguridad para controlar el tráfico

### `outputs.tf`
Define los valores de salida de la configuración.

**Outputs disponibles:**

1. **Resource Group:**
   - `resource_group_name`: Nombre del grupo de recursos

2. **Storage:**
   - `storage_account_name`: Nombre de la cuenta de almacenamiento

3. **Key Vault:**
   - `key_vault_uri`: URI del Key Vault

4. **Virtual Network:**
   - `vnet_id`: ID de la VNet
   - `vnet_name`: Nombre de la VNet

5. **Private Endpoints:**
   - `private_endpoint_storage_blob_id`: ID del endpoint de Storage Blob
   - `private_endpoint_storage_file_id`: ID del endpoint de Storage File
   - `private_endpoint_keyvault_id`: ID del endpoint de Key Vault

6. **Private DNS Zones:**
   - `private_dns_zones`: Mapa con nombres de las zonas DNS privadas

### `main.tf`
Archivo de referencia que indica que los recursos están organizados en archivos individuales.

**Nota:** Este archivo solo contiene comentarios explicando la estructura del proyecto.

## 🚀 Recursos Desplegados

La configuración crea los siguientes recursos en Azure:

1. **Resource Group** (1)
2. **Virtual Network** (1)
3. **Subnets** (N, según configuración)
4. **Network Security Groups** (N, uno por subnet)
5. **Storage Account** (1)
6. **Storage Container** (1)
7. **Key Vault** (1)
8. **Role Assignment** (1, para Key Vault)
9. **Private DNS Zones** (3)
10. **Private DNS Zone VNet Links** (6, 3 para cada VNet)
11. **Private Endpoints** (3)
12. **VNet Peerings** (2, bidireccional)

## 📋 Prerrequisitos

Antes de usar esta configuración, asegúrate de tener:

1. **Terraform** instalado (versión >= 1.6.0)
   - Descarga: https://developer.hashicorp.com/terraform/install

2. **Azure CLI** instalado y configurado
   - Descarga: https://learn.microsoft.com/cli/azure/install-azure-cli

3. **HashiCorp Vault** ejecutándose localmente
   - Debe estar accesible en `http://127.0.0.1:8200`
   - Debe tener un secret en `kv/spn/terraform-servicePrincipal` con:
     - `client_id`: ID del Service Principal de Azure
     - `client_secret`: Secret del Service Principal
     - `tenant_id`: ID del tenant de Azure AD
     - `subscription_id`: ID de la suscripción de Azure

4. **VNet existente** (opcional, para peering):
   - Nombre: "Vnet-Jumpbox"
   - Resource Group: "RG-VM-Jumpbox"
   - O modifica `data.tf` para usar tu VNet

5. **Permisos de Azure**:
   - Permisos para crear recursos en la suscripción
   - Permisos para crear role assignments

## ⚙️ Configuración

### 1. Configurar Vault

Asegúrate de que Vault esté ejecutándose y tenga el secret configurado:

```bash
# Ejemplo de cómo crear el secret en Vault
vault kv put kv/spn/terraform-servicePrincipal \
  client_id="<tu-client-id>" \
  client_secret="<tu-client-secret>" \
  tenant_id="<tu-tenant-id>" \
  subscription_id="<tu-subscription-id>"
```

### 2. Configurar Variables

Copia el archivo de ejemplo y personalízalo:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` con tus valores:

```hcl
environment = "dev"
tags = {
  owner = "tu-equipo"
}

resource_group_name = "rg-mi-proyecto"
location            = "eastus2"

vnet_name          = "vnet-mi-proyecto"
vnet_address_space = ["10.0.0.0/16"]

subnets = {
  subnet_app = {
    name              = "subnet-app"
    address_prefixes  = ["10.0.1.0/24"]
    service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
  }
  subnet_private_endpoints = {
    name              = "subnet-private-endpoints"
    address_prefixes  = ["10.0.4.0/24"]
    service_endpoints = []
  }
}

storage_account_name  = "mistorageaccount"
container_name        = "mi-contenedor"
container_access_type = "private"

key_vault_name = "mi-key-vault"
key_vault_sku  = "standard"
```

### 3. Inicializar Terraform

```bash
terraform init
```

## 🎮 Uso

### Planificar el Despliegue

```bash
terraform plan
```

### Aplicar la Configuración

```bash
terraform apply
```

### Verificar Outputs

```bash
terraform output
```

### Destruir la Infraestructura

```bash
terraform destroy
```

## 📊 Variables

### Variables de Configuración General

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `environment` | `string` | Identificador del entorno | `"dev"` |
| `tags` | `map(string)` | Etiquetas adicionales | `{}` |

### Variables de Resource Group

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `resource_group_name` | `string` | Nombre del grupo de recursos | *requerido* |
| `location` | `string` | Región de Azure | `"eastus"` |

### Variables de Virtual Network

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `vnet_name` | `string` | Nombre de la VNet | *requerido* |
| `vnet_address_space` | `list(string)` | Espacio de direcciones | `["10.0.0.0/16"]` |
| `subnets` | `map(object)` | Mapa de subredes | `{}` |

**Estructura de `subnets`:**
```hcl
subnets = {
  subnet_key = {
    name              = string
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
    delegation = optional(object({
      name = string
      service_delegation = object({
        name    = string
        actions = list(string)
      })
    }))
  }
}
```

### Variables de Storage Account

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `storage_account_name` | `string` | Nombre de la cuenta de almacenamiento | *requerido* |
| `container_name` | `string` | Nombre del contenedor | *requerido* |
| `container_access_type` | `string` | Tipo de acceso (private, blob, container) | `"private"` |

### Variables de Key Vault

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `key_vault_name` | `string` | Nombre del Key Vault | *requerido* |
| `key_vault_sku` | `string` | SKU (standard o premium) | `"standard"` |

## 📤 Outputs

| Output | Descripción |
|--------|-------------|
| `resource_group_name` | Nombre del grupo de recursos |
| `storage_account_name` | Nombre de la cuenta de almacenamiento |
| `key_vault_uri` | URI del Key Vault |
| `vnet_id` | ID de la Virtual Network |
| `vnet_name` | Nombre de la Virtual Network |
| `private_endpoint_storage_blob_id` | ID del private endpoint de Storage Blob |
| `private_endpoint_storage_file_id` | ID del private endpoint de Storage File |
| `private_endpoint_keyvault_id` | ID del private endpoint de Key Vault |
| `private_dns_zones` | Mapa con nombres de las Private DNS Zones |

## 📚 Referencias

### Documentación de Terraform

- [Terraform Language Documentation](https://developer.hashicorp.com/terraform/language)
- [Terraform Backends](https://developer.hashicorp.com/terraform/language/settings/backends/configuration)
- [Terraform Locals](https://developer.hashicorp.com/terraform/language/values/locals)
- [Terraform Outputs](https://developer.hashicorp.com/terraform/language/values/outputs)

### Proveedores de Terraform

- [Azure Provider (azurerm)](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Random Provider](https://registry.terraform.io/providers/hashicorp/random/latest/docs)
- [Vault Provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)

### Recursos de Azure

- [azurerm_resource_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group)
- [azurerm_virtual_network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network)
- [azurerm_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet)
- [azurerm_network_security_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group)
- [azurerm_storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account)
- [azurerm_key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault)
- [azurerm_private_endpoint](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint)
- [azurerm_private_dns_zone](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone)
- [azurerm_virtual_network_peering](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering)
- [azurerm_role_assignment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment)

### Data Sources

- [azurerm_client_config](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config)
- [azurerm_virtual_network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network)
- [vault_kv_secret_v2](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/data-sources/kv_secret_v2)

### Recursos de Random

- [random_string](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string)

## 🔒 Seguridad

### Características de Seguridad Implementadas

1. **Acceso Privado:**
   - Storage Account y Key Vault con `public_network_access_enabled = false`
   - Todos los servicios accesibles solo mediante Private Endpoints

2. **Private Endpoints:**
   - Endpoints privados para Storage (Blob y File) y Key Vault
   - Resolución DNS privada mediante Private DNS Zones

3. **Network Security:**
   - NSGs asociados a cada subnet
   - Service Endpoints configurados para servicios críticos
   - VNet Peering con configuración de seguridad

4. **RBAC:**
   - Key Vault con RBAC habilitado
   - Role assignment automático para el usuario actual

5. **Autenticación:**
   - Credenciales almacenadas en HashiCorp Vault
   - No hay credenciales hardcodeadas en el código

## 🐛 Troubleshooting

### Error: "Failed to get existing workspaces"

**Solución:** Verifica que Vault esté ejecutándose y accesible en `http://127.0.0.1:8200`

### Error: "Secret not found in Vault"

**Solución:** Asegúrate de que el secret existe en `kv/spn/terraform-servicePrincipal` con todas las claves requeridas

### Error: "Storage account name already exists"

**Solución:** El nombre de Storage Account debe ser único globalmente. El prefijo aleatorio ayuda, pero si persiste, cambia `storage_account_name`

### Error: "VNet peering failed"

**Solución:** Verifica que la VNet remota "Vnet-Jumpbox" existe en "RG-VM-Jumpbox", o modifica `data.tf` con tus valores

## 📝 Notas Adicionales

- El prefijo aleatorio se genera una vez y se mantiene en el estado de Terraform
- Los Private DNS Zones se crean en el mismo Resource Group que los recursos principales
- El VNet Peering requiere permisos en ambas VNets
- El Role Assignment para Key Vault se crea automáticamente para el usuario actual

## 👥 Contribuciones

Este proyecto es parte de la presentación para HashiTalk España 2026.

---

**Última actualización:** 2026
