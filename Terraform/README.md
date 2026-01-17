# Infraestructura Terraform - HashiTalk España 2026

Este proyecto de Terraform despliega una infraestructura segura en Azure con red privada, endpoints privados y recursos para cargas de trabajo RAG (Retrieval-Augmented Generation).

## 📋 Tabla de Contenidos

- [Descripción General](#descripción-general)
- [Arquitectura](#arquitectura)
- [Archivos de Configuración](#archivos-de-configuración)
- [Recursos Desplegados](#recursos-desplegados)
- [Prerrequisitos](#prerrequisitos)
- [Configuración desde Cero](#-configuración-desde-cero)
  - [Paso 1: Instalar Terraform](#paso-1-instalar-terraform)
  - [Paso 2: Instalar Azure CLI](#paso-2-instalar-azure-cli)
  - [Paso 3: Configurar Azure CLI](#paso-3-configurar-azure-cli)
  - [Paso 4: Crear Service Principal en Azure](#paso-4-crear-service-principal-en-azure)
  - [Paso 5: Instalar y Configurar HashiCorp Vault](#paso-5-instalar-y-configurar-hashicorp-vault)
  - [Paso 6: Iniciar y Configurar Vault](#paso-6-iniciar-y-configurar-vault)
  - [Paso 7: Verificar la Configuración](#paso-7-verificar-la-configuración)
  - [Paso 8: Configurar Variables de Terraform](#paso-8-configurar-variables-de-terraform)
  - [Paso 9: Configurar VNet Peering (Opcional)](#paso-9-configurar-vnet-peering-opcional)
  - [Paso 10: Inicializar Terraform](#paso-10-inicializar-terraform)
  - [Paso 11: Planificar el Despliegue](#paso-11-planificar-el-despliegue)
  - [Paso 12: Aplicar la Configuración](#paso-12-aplicar-la-configuración)
  - [Paso 13: Verificar el Despliegue](#paso-13-verificar-el-despliegue)
- [Configuración Rápida](#️-configuración-rápida)
- [Uso](#uso)
- [Variables](#variables)
- [Outputs](#outputs)
- [Troubleshooting](#-troubleshooting)
- [Mejores Prácticas](#-mejores-prácticas)
- [Destruir la Infraestructura](#-destruir-la-infraestructura)
- [Recursos de Aprendizaje](#-recursos-de-aprendizaje)
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

Antes de usar esta configuración, necesitas instalar y configurar las siguientes herramientas:

1. **Terraform** (versión >= 1.6.0)
2. **Azure CLI**
3. **HashiCorp Vault**
4. **Service Principal de Azure** con permisos adecuados
5. **VNet existente** (opcional, para peering)

## 🚀 Configuración desde Cero

Esta guía te llevará paso a paso desde la instalación hasta el despliegue completo.

### Paso 1: Instalar Terraform

#### Windows

1. **Descargar Terraform:**
   - Visita: https://developer.hashicorp.com/terraform/downloads
   - Descarga el archivo ZIP para Windows (amd64)

2. **Extraer y configurar:**
   ```powershell
   # Extraer el archivo ZIP a una carpeta (ej: C:\terraform)
   # Agregar al PATH del sistema:
   # 1. Abre "Variables de entorno" desde el Panel de Control
   # 2. Edita la variable PATH
   # 3. Agrega: C:\terraform
   ```

3. **Verificar instalación:**
   ```powershell
   terraform version
   ```
   Debe mostrar: `Terraform v1.6.0` o superior

#### Linux

```bash
# Instalar usando el gestor de paquetes
# Ubuntu/Debian:
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Verificar instalación
terraform version
```

#### macOS

```bash
# Instalar usando Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verificar instalación
terraform version
```

### Paso 2: Instalar Azure CLI

#### Windows

1. **Descargar instalador:**
   - Visita: https://aka.ms/installazurecliwindows
   - Descarga el instalador MSI

2. **Ejecutar instalador:**
   - Ejecuta el archivo `.msi` descargado
   - Sigue el asistente de instalación

3. **Verificar instalación:**
   ```powershell
   az --version
   ```

#### Linux

```bash
# Instalar usando el script oficial
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Verificar instalación
az --version
```

#### macOS

```bash
# Instalar usando Homebrew
brew install azure-cli

# Verificar instalación
az --version
```

### Paso 3: Configurar Azure CLI

1. **Iniciar sesión en Azure:**
   ```bash
   az login
   ```
   Esto abrirá tu navegador para autenticarte.

2. **Verificar suscripción activa:**
   ```bash
   az account show
   ```

3. **Si tienes múltiples suscripciones, selecciona una:**
   ```bash
   # Listar suscripciones
   az account list --output table
   
   # Establecer suscripción por defecto
   az account set --subscription "<SUBSCRIPTION_ID>"
   ```

### Paso 4: Crear Service Principal en Azure

El Service Principal es necesario para que Terraform se autentique con Azure usando credenciales almacenadas en Vault.

1. **Crear el Service Principal:**
   ```bash
   # Obtener tu Subscription ID
   SUBSCRIPTION_ID=$(az account show --query id -o tsv)
   
   # Crear Service Principal con permisos de Contributor
   az ad sp create-for-rbac \
     --name "terraform-sp-rag" \
     --role "Contributor" \
     --scopes "/subscriptions/$SUBSCRIPTION_ID" \
     --years 2
   ```

2. **Guardar las credenciales:**
   El comando anterior mostrará un JSON con las credenciales. **Guarda esta información de forma segura:**
   ```json
   {
     "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",  # client_id
     "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",     # client_secret
     "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"    # tenant_id
   }
   ```

3. **Obtener el Subscription ID:**
   ```bash
   az account show --query id -o tsv
   ```

4. **Asignar permisos adicionales (opcional):**
   ```bash
   # Si necesitas crear role assignments (para Key Vault RBAC)
   az role assignment create \
     --assignee <APP_ID> \
     --role "User Access Administrator" \
     --scope "/subscriptions/$SUBSCRIPTION_ID"
   ```

### Paso 5: Instalar y Configurar HashiCorp Vault

#### Windows

1. **Descargar Vault:**
   - Visita: https://developer.hashicorp.com/vault/downloads
   - Descarga el archivo ZIP para Windows (amd64)

2. **Extraer y configurar:**
   ```powershell
   # Extraer a C:\vault
   # Agregar C:\vault al PATH del sistema
   ```

3. **Verificar instalación:**
   ```powershell
   vault version
   ```

#### Linux

```bash
# Instalar usando el gestor de paquetes
# Ubuntu/Debian:
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault

# Verificar instalación
vault version
```

#### macOS

```bash
# Instalar usando Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/vault

# Verificar instalación
vault version
```

### Paso 6: Iniciar y Configurar Vault

1. **Iniciar Vault en modo desarrollo (solo para pruebas):**
   ```bash
   # En una terminal, ejecuta:
   vault server -dev
   ```
   
   **⚠️ IMPORTANTE:** El modo desarrollo NO es seguro para producción. Guarda el `Root Token` que se muestra.

2. **En otra terminal, configurar variables de entorno:**
   ```bash
   # Windows PowerShell:
   $env:VAULT_ADDR="http://127.0.0.1:8200"
   $env:VAULT_TOKEN="<ROOT_TOKEN_DEL_PASO_ANTERIOR>"
   
   # Linux/macOS:
   export VAULT_ADDR="http://127.0.0.1:8200"
   export VAULT_TOKEN="<ROOT_TOKEN_DEL_PASO_ANTERIOR>"
   ```

3. **Habilitar el motor KV v2:**
   ```bash
   vault secrets enable -path=kv -version=2 kv
   ```

4. **Almacenar las credenciales del Service Principal:**
   ```bash
   # Reemplaza los valores con los obtenidos en el Paso 4
   vault kv put kv/spn/terraform-servicePrincipal \
     client_id="<TU_CLIENT_ID>" \
     client_secret="<TU_CLIENT_SECRET>" \
     tenant_id="<TU_TENANT_ID>" \
     subscription_id="<TU_SUBSCRIPTION_ID>"
   ```

5. **Verificar que el secreto se guardó correctamente:**
   ```bash
   vault kv get kv/spn/terraform-servicePrincipal
   ```

### Paso 7: Verificar la Configuración

1. **Verificar Terraform:**
   ```bash
   terraform version
   ```

2. **Verificar Azure CLI:**
   ```bash
   az account show
   ```

3. **Verificar Vault:**
   ```bash
   vault status
   vault kv get kv/spn/terraform-servicePrincipal
   ```

### Paso 8: Configurar Variables de Terraform

1. **Navegar al directorio de Terraform:**
   ```bash
   cd Terraform
   ```

2. **Copiar el archivo de ejemplo:**
   ```bash
   # Windows PowerShell:
   Copy-Item terraform.tfvars.example terraform.tfvars
   
   # Linux/macOS:
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Editar `terraform.tfvars` con tus valores:**
   ```hcl
   ##### Variables - Configuración de despliegue y etiquetado #####
   environment = "dev"
   tags = {
     owner = "tu-equipo"
   }
   
   ##### Variables - Resource Group #####
   resource_group_name = "rg-rag-dev"
   location            = "eastus2"
   
   ##### Variables - Virtual Network #####
   vnet_name          = "vnet-rag-dev"
   vnet_address_space = ["10.0.0.0/16"]
   
   subnets = {
     subnet_app = {
       name              = "subnet-app"
       address_prefixes  = ["10.0.1.0/24"]
       service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
     }
     subnet_data = {
       name              = "subnet-data"
       address_prefixes  = ["10.0.2.0/24"]
       service_endpoints = ["Microsoft.Storage", "Microsoft.Sql"]
     }
     subnet_ai = {
       name              = "subnet-ai"
       address_prefixes  = ["10.0.3.0/24"]
       service_endpoints = ["Microsoft.CognitiveServices"]
     }
     subnet_private_endpoints = {
       name              = "subnet-private-endpoints"
       address_prefixes  = ["10.0.4.0/24"]
       service_endpoints = []
     }
   }
   
   ##### Variables - Storage Account #####
   storage_account_name  = "ragstorageaccount"  # Solo minúsculas y números, 3-24 caracteres
   container_name        = "rag-container"
   container_access_type = "private"
   
   ##### Variables - Key Vault #####
   key_vault_name = "rag-key-vault"  # Solo letras, números y guiones
   key_vault_sku  = "standard"
   ```

   **Notas importantes:**
   - `storage_account_name`: Debe ser único globalmente, solo minúsculas y números, entre 3-24 caracteres
   - `key_vault_name`: Solo letras, números y guiones, debe ser único globalmente
   - `vnet_address_space`: No debe solaparse con otras VNets si planeas hacer peering

### Paso 9: Configurar VNet Peering (Opcional)

Si necesitas hacer peering con una VNet existente:

1. **Editar `data.tf`:**
   ```hcl
   data "azurerm_virtual_network" "vnet-vm" {
     name                = "Vnet-Jumpbox"  # Cambia por el nombre de tu VNet
     resource_group_name = "RG-VM-Jumpbox"  # Cambia por tu Resource Group
   }
   ```

2. **Si no necesitas peering, puedes comentar o eliminar esta sección en `peering.tf` y `private_endpoints.tf`**

### Paso 10: Inicializar Terraform

1. **Inicializar Terraform:**
   ```bash
   terraform init
   ```
   
   Esto descargará los proveedores necesarios (azurerm, random, vault).

2. **Verificar que la conexión a Vault funciona:**
   ```bash
   terraform plan
   ```
   
   Si hay errores de autenticación con Vault, verifica:
   - Que Vault esté ejecutándose (`vault status`)
   - Que las variables de entorno `VAULT_ADDR` y `VAULT_TOKEN` estén configuradas
   - Que el secreto exista en Vault (`vault kv get kv/spn/terraform-servicePrincipal`)

### Paso 11: Planificar el Despliegue

```bash
terraform plan
```

Este comando mostrará todos los recursos que se crearán. Revisa cuidadosamente la salida.

### Paso 12: Aplicar la Configuración

```bash
terraform apply
```

Terraform te pedirá confirmación. Escribe `yes` para proceder.

**⏱️ Tiempo estimado:** El despliegue completo puede tardar entre 10-20 minutos.

### Paso 13: Verificar el Despliegue

1. **Ver los outputs:**
   ```bash
   terraform output
   ```

2. **Verificar recursos en Azure Portal:**
   - Visita: https://portal.azure.com
   - Navega al Resource Group creado
   - Verifica que todos los recursos estén desplegados correctamente

### Permisos Requeridos en Azure

El Service Principal necesita los siguientes permisos:

- **Contributor** a nivel de suscripción (para crear recursos)
- **User Access Administrator** (opcional, solo si necesitas crear role assignments)

Para verificar permisos:
```bash
az role assignment list \
  --assignee <APP_ID> \
  --all \
  --output table
```

## ⚙️ Configuración Rápida

Si ya tienes todas las herramientas instaladas, sigue estos pasos:

### 1. Configurar Variables

Copia el archivo de ejemplo y personalízalo:

```bash
# Windows PowerShell:
Copy-Item terraform.tfvars.example terraform.tfvars

# Linux/macOS:
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` con tus valores (ver [Paso 8](#paso-8-configurar-variables-de-terraform) para detalles completos).

### 2. Verificar Vault

Asegúrate de que Vault esté ejecutándose y tenga el secret configurado:

```bash
# Verificar que Vault está corriendo
vault status

# Verificar que el secreto existe
vault kv get kv/spn/terraform-servicePrincipal
```

Si el secreto no existe, créalo:

```bash
vault kv put kv/spn/terraform-servicePrincipal \
  client_id="<tu-client-id>" \
  client_secret="<tu-client-secret>" \
  tenant_id="<tu-tenant-id>" \
  subscription_id="<tu-subscription-id>"
```

### 3. Inicializar Terraform

```bash
terraform init
```

**📖 Para una guía completa desde cero, consulta la sección [Configuración desde Cero](#-configuración-desde-cero)**

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

### Error: "Failed to get existing workspaces" o "Error reading from Vault"

**Causa:** Vault no está accesible o no está configurado correctamente.

**Solución:**
```bash
# 1. Verificar que Vault está ejecutándose
vault status

# 2. Verificar variables de entorno
# Windows PowerShell:
echo $env:VAULT_ADDR
echo $env:VAULT_TOKEN

# Linux/macOS:
echo $VAULT_ADDR
echo $VAULT_TOKEN

# 3. Si faltan, configurarlas:
# Windows PowerShell:
$env:VAULT_ADDR="http://127.0.0.1:8200"
$env:VAULT_TOKEN="<TU_TOKEN>"

# Linux/macOS:
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="<TU_TOKEN>"
```

### Error: "Secret not found in Vault" o "Error reading secret"

**Causa:** El secreto no existe o el path es incorrecto.

**Solución:**
```bash
# 1. Verificar que el motor KV v2 está habilitado
vault secrets list

# 2. Si no existe, habilitarlo:
vault secrets enable -path=kv -version=2 kv

# 3. Verificar que el secreto existe:
vault kv get kv/spn/terraform-servicePrincipal

# 4. Si no existe, crearlo:
vault kv put kv/spn/terraform-servicePrincipal \
  client_id="<valor>" \
  client_secret="<valor>" \
  tenant_id="<valor>" \
  subscription_id="<valor>"
```

### Error: "Storage account name already exists"

**Causa:** El nombre de Storage Account debe ser único globalmente en Azure.

**Solución:**
```bash
# 1. Verificar si el nombre está disponible:
az storage account check-name --name <nombre> --query nameAvailable

# 2. Cambiar el nombre en terraform.tfvars:
storage_account_name = "nuevonombreunico123"
```

### Error: "Key Vault name already exists"

**Causa:** El nombre de Key Vault debe ser único globalmente.

**Solución:**
```bash
# Cambiar el nombre en terraform.tfvars:
key_vault_name = "nuevo-key-vault-nombre-123"
```

### Error: "VNet peering failed" o "Virtual network not found"

**Causa:** La VNet remota no existe o los nombres son incorrectos.

**Solución:**
```bash
# 1. Verificar que la VNet existe:
az network vnet show \
  --name "Vnet-Jumpbox" \
  --resource-group "RG-VM-Jumpbox"

# 2. Si no existe o tiene otro nombre, editar data.tf:
data "azurerm_virtual_network" "vnet-vm" {
  name                = "<TU_VNET_NAME>"
  resource_group_name = "<TU_RESOURCE_GROUP>"
}

# 3. Si no necesitas peering, comentar las secciones en peering.tf
```

### Error: "Authentication failed" o "Invalid credentials"

**Causa:** Las credenciales del Service Principal son incorrectas o han expirado.

**Solución:**
```bash
# 1. Verificar credenciales en Vault:
vault kv get kv/spn/terraform-servicePrincipal

# 2. Probar autenticación con Azure CLI:
az login --service-principal \
  --username <client_id> \
  --password <client_secret> \
  --tenant <tenant_id>

# 3. Si falla, crear un nuevo Service Principal (ver Paso 4)
```

### Error: "Insufficient permissions" o "Authorization failed"

**Causa:** El Service Principal no tiene los permisos necesarios.

**Solución:**
```bash
# 1. Verificar permisos actuales:
az role assignment list \
  --assignee <APP_ID> \
  --all \
  --output table

# 2. Asignar rol Contributor:
az role assignment create \
  --assignee <APP_ID> \
  --role "Contributor" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>"

# 3. Si necesitas crear role assignments:
az role assignment create \
  --assignee <APP_ID> \
  --role "User Access Administrator" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>"
```

### Error: "Address space overlaps" o "Subnet address space conflicts"

**Causa:** El espacio de direcciones de la VNet o subredes se solapa con otra VNet.

**Solución:**
```bash
# 1. Verificar espacios de direcciones existentes:
az network vnet list --query "[].{Name:name, AddressSpace:addressSpace.addressPrefixes}" -o table

# 2. Cambiar el espacio de direcciones en terraform.tfvars:
vnet_address_space = ["10.1.0.0/16"]  # Usar un rango diferente
```

### Error: "Terraform version mismatch"

**Causa:** La versión de Terraform es inferior a la requerida (1.6.0).

**Solución:**
```bash
# 1. Verificar versión actual:
terraform version

# 2. Actualizar Terraform (ver Paso 1 de la guía de instalación)
```

### Error: "Provider initialization failed"

**Causa:** Los proveedores no se descargaron correctamente.

**Solución:**
```bash
# 1. Limpiar caché de proveedores:
rm -rf .terraform .terraform.lock.hcl

# 2. Re-inicializar:
terraform init -upgrade
```

### Error: "Backend configuration changed"

**Causa:** La configuración del backend cambió después de la inicialización.

**Solución:**
```bash
# Si cambiaste el backend, necesitas migrar el estado:
terraform init -migrate-state
```

### Problemas Comunes con Vault en Modo Desarrollo

**⚠️ IMPORTANTE:** El modo desarrollo de Vault reinicia los datos al reiniciar el servidor.

**Solución para producción:**
- Usa Vault en modo servidor con almacenamiento persistente
- Configura políticas de acceso adecuadas
- Usa tokens con TTL apropiado
- Consulta la documentación oficial: https://developer.hashicorp.com/vault/docs

## 📝 Notas Adicionales

- El prefijo aleatorio se genera una vez y se mantiene en el estado de Terraform
- Los Private DNS Zones se crean en el mismo Resource Group que los recursos principales
- El VNet Peering requiere permisos en ambas VNets
- El Role Assignment para Key Vault se crea automáticamente para el usuario actual

## 💡 Mejores Prácticas

### Gestión del Estado de Terraform

1. **Backend Remoto (Recomendado para Producción):**
   ```hcl
   # En backend.tf, cambiar de local a Azure Storage:
   terraform {
     backend "azurerm" {
       resource_group_name  = "rg-terraform-state"
       storage_account_name = "terraformstate"
       container_name       = "tfstate"
       key                  = "rag-infrastructure.terraform.tfstate"
     }
   }
   ```

2. **Protección del Estado:**
   - Habilitar versionado en el Storage Account del backend
   - Usar bloqueo (blob lease) para prevenir escrituras concurrentes
   - Hacer backups regulares del archivo de estado

### Seguridad

1. **Vault en Producción:**
   - NO usar modo desarrollo en producción
   - Configurar almacenamiento persistente (Consul, etcd, etc.)
   - Implementar políticas de acceso granulares
   - Usar tokens con TTL apropiado

2. **Service Principal:**
   - Rotar credenciales regularmente
   - Usar el principio de menor privilegio
   - Monitorear el uso del Service Principal

3. **Variables Sensibles:**
   - Nunca commitear `terraform.tfvars` con valores reales
   - Usar `.gitignore` para excluir archivos sensibles
   - Considerar usar Azure Key Vault para variables de Terraform

### Gestión de Recursos

1. **Etiquetado:**
   - Usar etiquetas consistentes para facilitar la gestión
   - Incluir información de costo, entorno, y propietario

2. **Nombres de Recursos:**
   - Seguir convenciones de nomenclatura consistentes
   - El prefijo aleatorio ayuda a evitar conflictos

3. **Destrucción Segura:**
   ```bash
   # Siempre revisar el plan antes de destruir
   terraform plan -destroy
   
   # Destruir recursos específicos si es necesario
   terraform destroy -target=azurerm_resource_group.rag
   ```

### Monitoreo y Mantenimiento

1. **Verificar Estado Regularmente:**
   ```bash
   terraform state list
   terraform show
   ```

2. **Actualizar Proveedores:**
   ```bash
   terraform init -upgrade
   ```

3. **Validar Configuración:**
   ```bash
   terraform validate
   terraform fmt -check
   ```

## 🔄 Destruir la Infraestructura

### Destrucción Completa

```bash
# 1. Revisar qué se destruirá
terraform plan -destroy

# 2. Confirmar y destruir
terraform destroy
```

### Destrucción Parcial

```bash
# Destruir un recurso específico
terraform destroy -target=azurerm_storage_account.rag

# Destruir múltiples recursos
terraform destroy \
  -target=azurerm_storage_account.rag \
  -target=azurerm_key_vault.rag
```

### Consideraciones Importantes

1. **Private Endpoints:** Se destruyen automáticamente con los recursos asociados
2. **VNet Peering:** Requiere permisos en ambas VNets para destruir
3. **Key Vault:** Si tiene purge protection, puede requerir pasos adicionales
4. **Estado de Terraform:** El archivo de estado se mantiene después de `destroy`

## 🎓 Recursos de Aprendizaje

### Documentación Oficial

- [Terraform para Azure](https://learn.microsoft.com/azure/developer/terraform/)
- [HashiCorp Vault](https://developer.hashicorp.com/vault/docs)
- [Azure Provider para Terraform](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### Tutoriales Recomendados

- [Terraform en Azure - Microsoft Learn](https://learn.microsoft.com/azure/developer/terraform/get-started-cloud-shell)
- [Vault Getting Started](https://developer.hashicorp.com/vault/tutorials/getting-started)
- [Azure Private Endpoints](https://learn.microsoft.com/azure/private-link/private-endpoint-overview)

## 👥 Contribuciones

Este proyecto es parte de la presentación para HashiTalk España 2026.

---

**Última actualización:** 2026
