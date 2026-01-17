# Demo: Infra privada de Azure + OPA + Vault

Este repositorio contiene una demostración completa de cómo construir una infraestructura segura en Azure usando tres herramientas modernas de DevOps: **Terraform**, **HashiCorp Vault** y **Open Policy Agent (OPA)**.

## 🎯 ¿Qué aprenderás?

Este proyecto te enseñará:

- ✅ **Terraform**: Cómo definir infraestructura como código en Azure
- ✅ **HashiCorp Vault**: Cómo gestionar secretos de forma segura
- ✅ **OPA**: Cómo validar políticas de seguridad antes de aplicar cambios
- ✅ **Azure Networking**: Private Endpoints, Private DNS Zones, Azure Bastion
- ✅ **Seguridad en la Nube**: Redes privadas, acceso restringido, validación automática

## 🏗️ Componentes del Proyecto

### 1. **Terraform/** - Infraestructura como Código
Define y despliega recursos de Azure de forma declarativa:
- Virtual Network (VNet) con subredes dedicadas
- Network Security Groups (NSG)
- Azure Bastion Host para acceso seguro a VMs
- Windows Virtual Machine con Azure AD Login
- Private Endpoints para Storage y Key Vault
- Private DNS Zones para resolución DNS privada
- Storage Account con acceso privado
- Key Vault con RBAC habilitado

📖 **[Ver documentación completa de Terraform →](Terraform/README.md)**

### 2. **Vault/** - Gestión Segura de Secretos
Almacena credenciales de Azure de forma encriptada:
- Configuración local de HashiCorp Vault
- Almacenamiento de Service Principal de Azure
- Integración con Terraform para autenticación automática
- Políticas de acceso granulares

📖 **[Ver documentación completa de Vault →](Vault/README.md)**

### 3. **OPA/** - Validación de Políticas
Valida que los recursos no tengan acceso público habilitado:
- Política Rego que prohíbe exposición a Internet
- Script PowerShell para evaluación automática
- Integración con CI/CD para validación continua
- Detección de configuraciones inseguras

📖 **[Ver documentación completa de OPA →](OPA/README.md)**

## 🚀 Inicio Rápido

Si ya tienes experiencia con estas herramientas, consulta las guías rápidas en cada directorio. Si estás aprendiendo, te recomendamos seguir el orden:

1. **Primero**: Lee y configura [Vault](Vault/README.md) - Necesitas almacenar credenciales
2. **Segundo**: Revisa y despliega con [Terraform](Terraform/README.md) - Crea la infraestructura
3. **Tercero**: Valida con [OPA](OPA/README.md) - Asegura que todo esté configurado correctamente

## 📚 Para Principiantes

Cada directorio contiene documentación completa diseñada para personas que están aprendiendo:

- **Conceptos básicos** explicados desde cero
- **Instalación paso a paso** para Windows, Linux y macOS
- **Ejemplos prácticos** con explicaciones detalladas
- **Solución de problemas** para errores comunes
- **Recursos de aprendizaje** adicionales

### Orden de Aprendizaje Recomendado

Si es tu primera vez con estas herramientas, te recomendamos seguir este orden:

#### 1️⃣ **Primero: HashiCorp Vault** (30-45 minutos)
- **Por qué primero**: Necesitas almacenar las credenciales de Azure antes de usar Terraform
- **Qué aprenderás**:
  - Conceptos básicos de gestión de secretos
  - Cómo instalar y configurar Vault
  - Cómo almacenar y leer secretos
  - Políticas de acceso y tokens
- **📖 [Empezar con Vault →](Vault/README.md)**

#### 2️⃣ **Segundo: Terraform** (1-2 horas)
- **Por qué segundo**: Usa las credenciales de Vault para crear recursos en Azure
- **Qué aprenderás**:
  - Conceptos de Infrastructure as Code
  - Sintaxis HCL (HashiCorp Configuration Language)
  - Cómo crear recursos en Azure
  - Variables, outputs y state management
- **📖 [Empezar con Terraform →](Terraform/README.md)**

#### 3️⃣ **Tercero: Open Policy Agent** (30-45 minutos)
- **Por qué tercero**: Valida los planes de Terraform antes de aplicar cambios
- **Qué aprenderás**:
  - Conceptos de políticas como código
  - Lenguaje Rego básico
  - Cómo validar planes de Terraform
  - Integración con CI/CD
- **📖 [Empezar con OPA →](OPA/README.md)**

### Tiempo Total Estimado

- **Principiante completo**: 3-4 horas (incluyendo instalación y configuración)
- **Con experiencia previa**: 1-2 horas (solo configuración del proyecto)
- **Solo revisión**: 30 minutos (entender la arquitectura)

### Prerrequisitos

Antes de comenzar, asegúrate de tener:

- ✅ Una cuenta de Azure con suscripción activa
- ✅ Permisos para crear recursos (Contributor o Owner)
- ✅ Windows, Linux o macOS con PowerShell o Bash
- ✅ Conexión a Internet para descargar herramientas

A continuación verás cómo está armado, cómo ejecutarlo en Windows (PowerShell) y cómo validar que nada quede con acceso público.

## 🔄 Flujo de Trabajo Completo

Este proyecto demuestra cómo tres herramientas trabajan juntas para crear infraestructura segura:

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Vault    │─────▶│  Terraform  │─────▶│    OPA      │
│            │      │             │      │             │
│ Almacena   │      │ Crea        │      │ Valida      │
│ credenciales│      │ recursos    │      │ políticas   │
└─────────────┘      └─────────────┘      └─────────────┘
     │                     │                     │
     │                     │                     │
     └─────────────────────┴─────────────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │    Azure    │
                    │ Infraestructura│
                    └─────────────┘
```

### Paso a Paso

1. **Vault** almacena las credenciales de Azure de forma segura
2. **Terraform** lee las credenciales de Vault y genera un plan de infraestructura
3. **OPA** valida el plan antes de aplicar cambios
4. Si OPA aprueba, **Terraform** crea los recursos en Azure
5. La infraestructura queda desplegada de forma segura

### Beneficios de esta Integración

✅ **Seguridad**: Credenciales nunca en código o archivos  
✅ **Validación**: Políticas aplicadas antes de crear recursos  
✅ **Automatización**: Todo el proceso es repetible y versionable  
✅ **Auditoría**: Cada paso queda registrado y documentado

## 🏗️ Arquitectura Resumida

- **Red**
  - VNet principal con subnets configurables (incluyendo subnet para Azure Bastion y subnet para VM)
  - NSGs por subnet (excepto subnet de Bastion)
  - Azure Bastion Host para acceso seguro a VMs
  - Private Endpoints para: Storage (Blob/File) y Key Vault
  - Private DNS Zones enlazadas a la VNet local
- **Compute**
  - Windows Virtual Machine (Standard_B2s, Windows Server 2022)
  - Azure AD Login habilitado (sin necesidad de contraseñas locales)
  - Acceso mediante Azure Bastion (sin exponer RDP públicamente)
- **Servicios de datos y secretos**
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
- `vnet.tf`: VNet, subnets, NSGs, Azure Bastion Host y Public IP
- `vm.tf`: Virtual Machine Windows, Network Interface, VM Extension y Role Assignments
- `private_endpoints.tf`: Private Endpoints + Private DNS Zones y VNet Links
- `storage.tf`: Storage Account (acceso público deshabilitado)
- `key_vault.tf`: Key Vault (RBAC, acceso público deshabilitado) y Role Assignment
- `outputs.tf`: Salidas útiles (ids, nombres, DNS zones, IPs, etc.)
- `variables.tf` y `locals.tf`: variables de entrada y etiquetas comunes
- `backend.tf`: backend local por defecto
- `vault.tf`: Configuración del proveedor Vault y data source para credenciales
- `data.tf`: Data sources (configuración del cliente Azure)
- `random.tf`: Generación de prefijo aleatorio y contraseña para la VM
- `main.tf`: Archivo de referencia (recursos organizados en archivos individuales)

### Variables clave (extracto)

- Despliegue y tagging: `environment`, `tags`
- RG y región: `resource_group_name`, `location`
- Red: `vnet_name`, `vnet_address_space`, `subnets` (mapa con name/prefixes/optional delegation/service_endpoints)
  - **Importante**: Requiere una subnet llamada `subnet_bastion` con nombre `AzureBastionSubnet` y tamaño mínimo `/26`
- Storage: `storage_account_name`
- Key Vault: `key_vault_name`, `key_vault_sku`
- Virtual Machine: `vm_azure_ad_group_object_id` (Object ID del grupo de Azure AD con acceso a la VM)
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
  - Revisa los `private_dns_zone_virtual_network_link` para la VNet local
  - Verifica que las Private DNS Zones estén correctamente enlazadas
- Azure Bastion y VM
  - Verifica que la subnet `subnet_bastion` tenga el nombre exacto `AzureBastionSubnet` y tamaño mínimo `/26`
  - Asegúrate de que el grupo de Azure AD especificado en `vm_azure_ad_group_object_id` existe y tiene miembros
  - Para acceder a la VM, usa Azure Bastion desde el portal de Azure (no RDP directo)
- Permisos
  - El principal usado debe tener permisos suficientes (Owner/Contributor) para crear todos los recursos
  - Para crear la VM y asignar roles, necesitas permisos de User Access Administrator o Owner

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

Hecho para HUG Panama. Ajusta nombres/regiones según tu suscripción.
