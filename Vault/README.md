# HashiCorp Vault - Configuración y Documentación

Este directorio contiene la configuración y datos de HashiCorp Vault para el entorno de desarrollo local. Vault se utiliza para almacenar de forma segura las credenciales de Azure que consume Terraform, evitando exponer secretos en archivos de configuración.

## 📁 Estructura de Directorios

```
Vault/
├── config/                    # Archivos de configuración
│   ├── vault.hcl             # Configuración activa de Vault
│   └── vault.hcl.example     # Archivo de ejemplo para configuración
├── core/                      # Datos del núcleo de Vault (no modificar manualmente)
├── data/                      # Directorio de datos adicionales
├── logical/                   # Datos lógicos (secrets engines, mounts)
├── logs/                      # Logs de Vault
│   └── vault.txt             # Archivo de log principal
├── sys/                       # Sistema interno de Vault
└── init.txt                   # Archivo con keys de unseal y root token (SOLO DEMO)
```

**⚠️ ADVERTENCIA DE SEGURIDAD**: Los directorios `core/`, `logical/`, `sys/` y `data/` contienen información sensible y encriptada. **NUNCA** los compartas, commitees a repositorios públicos, o expongas. El archivo `init.txt` contiene credenciales de demostración y **NO debe usarse en producción**.

---

## 📄 Documentación de Archivos de Ejemplo

### `config/vault.hcl.example`

Este archivo es una plantilla de configuración para HashiCorp Vault en un entorno de desarrollo local en Windows. Proporciona una configuración mínima funcional para desarrollo y pruebas.

#### Descripción de Parámetros

```hcl
storage "file" {
  # Configuración del backend de almacenamiento
  # En Windows, usa barras normales (/) o escapa las barras invertidas (\\)
  # Ejemplo con barras normales para evitar errores de escape:
  path = "C:\\Vault"
}
```

- **`storage "file"`**: Define el backend de almacenamiento como sistema de archivos local
- **`path`**: Ruta absoluta donde Vault almacenará sus datos encriptados
  - En Windows, puedes usar barras normales `/` o barras invertidas escapadas `\\`
  - Ejemplo: `path = "C:/Vault"` o `path = "C:\\Vault"`
  - **Importante**: Asegúrate de que el directorio exista o que Vault tenga permisos para crearlo

```hcl
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
```

- **`listener "tcp"`**: Configura el listener de red para aceptar conexiones
- **`address`**: Dirección IP y puerto donde Vault escuchará
  - `0.0.0.0:8200` significa que escuchará en todas las interfaces de red en el puerto 8200
  - Para solo localhost, usa `127.0.0.1:8200`
- **`tls_disable = 1`**: Deshabilita TLS/SSL (solo para desarrollo)
  - **⚠️ NUNCA uses esto en producción**. En producción, configura certificados TLS apropiados

```hcl
# Requerido en Windows
disable_mlock = true
```

- **`disable_mlock`**: Deshabilita el bloqueo de memoria (mlock)
- **Requerido en Windows**: Windows no soporta mlock de la misma manera que Linux/Unix
- En Linux/Unix, mlock previene que la memoria se escriba al swap, mejorando la seguridad
- En producción en Linux, considera usar `disable_mlock = false` si es posible

```hcl
# UI web opcional
ui = true
```

- **`ui = true`**: Habilita la interfaz web de Vault
- Permite acceder a Vault a través de un navegador en `http://127.0.0.1:8200/ui`
- Útil para desarrollo y administración visual

```hcl
# La URL que Vault anuncia a los clientes
api_addr = "http://127.0.0.1:8200"
```

- **`api_addr`**: URL base que Vault anuncia a los clientes para conectarse
- Debe coincidir con la dirección del listener
- Los clientes (como Terraform) usarán esta URL para conectarse a Vault
- En producción con TLS, usaría `https://` en lugar de `http://`

#### Configuración Personalizada

Para usar este archivo de ejemplo:

1. **Copia el archivo de ejemplo**:
   ```powershell
   Copy-Item .\config\vault.hcl.example .\config\vault.hcl
   ```

2. **Ajusta la ruta de almacenamiento**:
   ```hcl
   storage "file" {
     path = "C:\\Users\\TuUsuario\\Vault"  # Ajusta según tu entorno
   }
   ```

3. **Verifica la dirección del listener** (opcional, si necesitas cambiar el puerto):
   ```hcl
   listener "tcp" {
     address     = "127.0.0.1:8200"  # Solo localhost para mayor seguridad
     tls_disable = 1
   }
   ```

4. **Ajusta `api_addr`** si cambiaste el listener:
   ```hcl
   api_addr = "http://127.0.0.1:8200"
   ```

---

### `init.txt`

Este archivo contiene la salida del comando `vault operator init` y contiene información crítica para acceder a Vault.

#### ⚠️ ADVERTENCIA CRÍTICA

**Este archivo contiene credenciales reales de acceso a Vault.**
- **NO** lo commitees a repositorios públicos o privados
- **NO** lo compartas con personas no autorizadas
- **NO** lo uses en producción sin rotar las credenciales
- Este archivo es **SOLO para demostración y desarrollo local**

#### Contenido del Archivo

```
Unseal Key 1: <UNSEAL_KEY_1>
Unseal Key 2: <UNSEAL_KEY_2>
Unseal Key 3: <UNSEAL_KEY_3>
Unseal Key 4: <UNSEAL_KEY_4>
Unseal Key 5: <UNSEAL_KEY_5>

Initial Root Token: <ROOT_TOKEN>

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

#### Explicación de Componentes

1. **Unseal Keys (Llaves de Desbloqueo)**
   - **Cantidad**: 5 llaves generadas
   - **Threshold (Umbral)**: Se requieren 3 de las 5 llaves para desbloquear Vault
   - **Propósito**: Vault usa un esquema de "Shamir Secret Sharing" para proteger la clave maestra
   - **Uso**: Cuando Vault se reinicia o se sella, necesitas proporcionar al menos 3 llaves para desbloquearlo
   - **Distribución**: En producción, distribuye estas llaves entre diferentes personas/ubicaciones seguras

2. **Initial Root Token (Token Raíz Inicial)**
   - **Formato**: `hvs.XXXXXXXXXXXXXX` (ejemplo - reemplaza con tu token real)
   - **Propósito**: Token de administrador con permisos completos en Vault
   - **Uso**: Se usa para la configuración inicial y creación de políticas/usuarios
   - **Seguridad**: 
     - **ROTA este token inmediatamente después de la configuración inicial**
     - Crea tokens con permisos limitados para uso diario
     - El root token debe guardarse en una ubicación ultra-segura (caja fuerte, gestor de secretos empresarial)

3. **Información de Configuración**
   - **Key Shares**: 5 (número total de llaves generadas)
   - **Key Threshold**: 3 (número mínimo de llaves requeridas)
   - Esta configuración es un balance entre seguridad y disponibilidad

#### Mejores Prácticas

1. **Almacenamiento Seguro**:
   - Guarda las Unseal Keys en ubicaciones físicas separadas
   - Usa un gestor de secretos empresarial (como Azure Key Vault, AWS Secrets Manager)
   - Considera usar "Auto-unseal" en producción (Azure Key Vault, AWS KMS, etc.)

2. **Rotación de Credenciales**:
   - Rota el root token después de la configuración inicial
   - Considera rotar las unseal keys periódicamente usando `vault operator rekey`

3. **Backup**:
   - Haz backup del directorio de datos de Vault regularmente
   - Guarda las unseal keys en múltiples ubicaciones seguras
   - Documenta el proceso de recuperación

---

## ✅ Checklist Rápido de Configuración

Antes de comenzar, verifica que tengas:

- [ ] HashiCorp Vault instalado (`vault version`)
- [ ] Puerto 8200 disponible o configurado otro puerto
- [ ] Permisos para crear directorios en la ruta de storage
- [ ] Credenciales de Azure (Service Principal):
  - [ ] `tenant_id`
  - [ ] `subscription_id`
  - [ ] `client_id`
  - [ ] `client_secret`
- [ ] Acceso a una terminal PowerShell

**Tiempo estimado de configuración completa**: 15-30 minutos

---

## 🚀 Proceso de Configuración de HashiCorp Vault

### Prerrequisitos

1. **Instalar HashiCorp Vault**:
   
   **Opción 1: Usando Chocolatey (Recomendado en Windows)**
   ```powershell
   # Instalar Chocolatey si no lo tienes (ejecutar como Administrador)
   Set-ExecutionPolicy Bypass -Scope Process -Force
   [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
   iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
   
   # Instalar Vault
   choco install vault -y
   ```
   
   **Opción 2: Descarga Manual**
   ```powershell
   # 1. Visita https://developer.hashicorp.com/vault/downloads
   # 2. Descarga la versión para Windows (amd64)
   # 3. Extrae el ejecutable vault.exe
   # 4. Colócalo en una carpeta (ej: C:\HashiCorp\vault\)
   # 5. Agrega la carpeta al PATH del sistema:
   #    - Abre "Variables de entorno" desde el Panel de Control
   #    - Edita la variable PATH
   #    - Agrega: C:\HashiCorp\vault\
   ```
   
   **Opción 3: Usando Scoop**
   ```powershell
   # Instalar Scoop si no lo tienes
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   irm get.scoop.sh | iex
   
   # Instalar Vault
   scoop install vault
   ```

2. **Verificar la Instalación**:
   ```powershell
   # Verificar que Vault está instalado y accesible
   vault version
   
   # Deberías ver algo como:
   # Vault v1.x.x (entrada: 2024-xx-xxTxx:xx:xxZ)
   ```
   
   Si obtienes un error "vault: command not found" o similar:
   - Verifica que Vault esté en el PATH: `$env:PATH`
   - Reinicia la terminal después de agregar Vault al PATH
   - Verifica la instalación: `Get-Command vault`

3. **Verificar que el puerto 8200 esté disponible**:
   ```powershell
   # Verificar si el puerto está en uso
   netstat -an | findstr :8200
   
   # Si hay resultados, significa que el puerto está ocupado
   # Opciones:
   # - Detén el proceso que usa el puerto
   # - Cambia el puerto en vault.hcl a otro (ej: 8201)
   ```

### Paso 1: Preparar la Configuración

1. **Navega al directorio Vault**:
   ```powershell
   cd .\DemoHashiTalkEspana2026\Vault
   ```

2. **Crea el archivo de configuración desde el ejemplo** (si no existe):
   ```powershell
   if (-not (Test-Path .\config\vault.hcl)) {
       Copy-Item .\config\vault.hcl.example .\config\vault.hcl
   }
   ```

3. **Ajusta la ruta en `vault.hcl`** según tu entorno:
   ```powershell
   # Abre el archivo y modifica la ruta
   notepad .\config\vault.hcl
   ```
   
   Asegúrate de que la ruta en `storage "file"` apunte a un directorio existente o que Vault tenga permisos para crearlo.

### Paso 2: Inicializar Vault (Primera Vez)

1. **Inicia el servidor de Vault** en una terminal:
   ```powershell
   vault server -config .\config\vault.hcl
   ```
   
   Deberías ver un mensaje indicando que Vault está iniciado pero **sealed** (sellado):
   ```
   ==> Vault server started! Log data will stream in below:
   ...
   [INFO]  core: security barrier not initialized
   ```

2. **En otra terminal, inicializa Vault**:
   ```powershell
   # Configura la dirección de Vault
   $env:VAULT_ADDR = "http://127.0.0.1:8200"
   
   # Inicializa Vault (solo la primera vez)
   vault operator init
   ```

3. **Guarda la salida de forma segura**:
   - Copia las 5 Unseal Keys
   - Copia el Initial Root Token
   - **Guarda esta información en un lugar seguro** (no en el repositorio)
   - El archivo `init.txt` en este directorio es solo un ejemplo de cómo se ve la salida

### Paso 3: Desbloquear (Unseal) Vault

Después de inicializar, Vault está sellado. Necesitas desbloquearlo con las Unseal Keys:

```powershell
# Asegúrate de que VAULT_ADDR esté configurado
$env:VAULT_ADDR = "http://127.0.0.1:8200"

# Desbloquea con las primeras 3 Unseal Keys (necesitas el threshold)
vault operator unseal <UNSEAL_KEY_1>
vault operator unseal <UNSEAL_KEY_2>
vault operator unseal <UNSEAL_KEY_3>
```

Después de proporcionar 3 llaves, deberías ver:
```
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             false
...
```

### Paso 4: Autenticarse con el Root Token

```powershell
# Autentícate con el root token
vault login <ROOT_TOKEN>
```

O interactivamente:
```powershell
vault login
# Ingresa el root token cuando se solicite
```

### Paso 5: Configurar el Secrets Engine KV v2

Terraform necesita leer credenciales de Azure desde Vault. Configura el motor de secretos:

```powershell
# Habilita el secrets engine KV v2 en la ruta 'kv'
vault secrets enable -path=kv kv-v2
```

Verifica que esté habilitado:
```powershell
vault secrets list
```

Deberías ver:
```
Path          Type         Accessor              Description
----          ----         --------              -----------
cubbyhole/    cubbyhole    cubbyhole_xxx         per-token private secret storage
identity/     identity     identity_xxx           identity store
kv/           kv           kv_xxx                n/a
secret/       kv           kv_xxx                key/value secret storage
sys/          system       system_xxx             system endpoints used for control, policy and debugging
```

### Paso 6: Almacenar Credenciales de Azure

Terraform necesita leer las credenciales de Azure desde Vault. Según la configuración del proyecto, Terraform busca los secretos en la ruta `kv/spn/terraform-servicePrincipal`.

**Obtén las credenciales de Azure**:
- Necesitas un Service Principal de Azure con permisos para crear recursos
- Obtén: `tenant_id`, `subscription_id`, `client_id`, `client_secret`
- Si no tienes un Service Principal, créalo con:
  ```powershell
  # Conecta a Azure
  az login
  
  # Crea un Service Principal
  az ad sp create-for-rbac --name "terraform-sp" --role contributor --scopes /subscriptions/<SUBSCRIPTION_ID>
  
  # Guarda la salida que contiene: appId (client_id), password (client_secret), tenant
  ```

**Almacena las credenciales en Vault**:

**Opción 1: Usando el comando vault kv put (PowerShell)**:
```powershell
# IMPORTANTE: Usa la ruta exacta que Terraform espera
vault kv put kv/spn/terraform-servicePrincipal `
  tenant_id="<TU_TENANT_ID>" `
  subscription_id="<TU_SUBSCRIPTION_ID>" `
  client_id="<TU_CLIENT_ID>" `
  client_secret="<TU_CLIENT_SECRET>"
```

**Opción 2: Usando un archivo JSON**:
```powershell
# Crea un archivo temporal con las credenciales
$credenciales = @{
    tenant_id = "<TU_TENANT_ID>"
    subscription_id = "<TU_SUBSCRIPTION_ID>"
    client_id = "<TU_CLIENT_ID>"
    client_secret = "<TU_CLIENT_SECRET>"
}

# Guarda en Vault
$credenciales | ConvertTo-Json | vault kv put kv/spn/terraform-servicePrincipal -
```

**Opción 3: Desde un archivo JSON existente**:
```powershell
# Si tienes un archivo credenciales.json
Get-Content credenciales.json | vault kv put kv/spn/terraform-servicePrincipal -
```

**Verifica que se guardaron correctamente**:
```powershell
# Ver todos los campos
vault kv get kv/spn/terraform-servicePrincipal

# Ver un campo específico
vault kv get -field=tenant_id kv/spn/terraform-servicePrincipal
vault kv get -field=client_id kv/spn/terraform-servicePrincipal
```

**Estructura esperada en Vault**:
```
kv/
└── spn/
    └── terraform-servicePrincipal
        ├── tenant_id
        ├── subscription_id
        ├── client_id
        └── client_secret
```

### Paso 7: Crear un Token para Terraform (Recomendado)

En lugar de usar el root token, crea un token con permisos limitados solo para leer los secretos que Terraform necesita:

**Opción 1: Crear política desde archivo (PowerShell)**:
```powershell
# Crea un archivo con la política
@"
path "kv/data/spn/terraform-servicePrincipal" {
  capabilities = ["read"]
}

path "kv/metadata/spn/terraform-servicePrincipal" {
  capabilities = ["read", "list"]
}
"@ | Out-File -FilePath terraform-policy.hcl -Encoding utf8

# Crea la política en Vault
vault policy write terraform-policy terraform-policy.hcl

# Verifica la política
vault policy read terraform-policy
```

**Opción 2: Crear política directamente (si tu terminal soporta heredoc)**:
```powershell
# Crea una política que permita leer solo kv/spn/terraform-servicePrincipal
vault policy write terraform-policy - <<EOF
path "kv/data/spn/terraform-servicePrincipal" {
  capabilities = ["read"]
}

path "kv/metadata/spn/terraform-servicePrincipal" {
  capabilities = ["read", "list"]
}
EOF
```

**Crear el token**:
```powershell
# Crea un token con esta política (válido por 24 horas)
vault token create -policy=terraform-policy -ttl=24h

# O crea un token con TTL más largo (ej: 30 días)
vault token create -policy=terraform-policy -ttl=720h

# O crea un token sin expiración (solo para desarrollo)
vault token create -policy=terraform-policy -ttl=0
```

**Salida esperada**:
```
Key                  Value
---                  -----
token                hvs.CAESIQxxxxx...
token_accessor       xxxxx...
token_duration       24h
token_renewable      true
token_policies       ["default" "terraform-policy"]
identity_policies    []
policies             ["default" "terraform-policy"]
```

**⚠️ IMPORTANTE**: Copia el valor de `token` (comienza con `hvs.`). Este es el token que usarás con Terraform. Guárdalo de forma segura.

**Verificar que el token funciona**:
```powershell
# Autentícate con el nuevo token
vault login <TOKEN_GENERADO>

# Intenta leer el secreto (debe funcionar)
vault kv get kv/spn/terraform-servicePrincipal

# Intenta escribir (debe fallar - el token solo tiene permisos de lectura)
vault kv put kv/spn/test key=value
# Error esperado: permission denied
```

### Paso 8: Configurar Variables de Entorno para Terraform

Terraform necesita dos variables de entorno para conectarse a Vault:
1. `VAULT_ADDR`: La dirección de Vault
2. `TF_VAR_vault_token` o `VAULT_TOKEN`: El token de autenticación

**Configuración Temporal (solo para la sesión actual)**:
```powershell
# Configura la dirección de Vault
$env:VAULT_ADDR = "http://127.0.0.1:8200"

# Configura el token de Vault para Terraform
$env:TF_VAR_vault_token = "<TOKEN_GENERADO_EN_PASO_7>"

# O usa VAULT_TOKEN (alternativa)
# $env:VAULT_TOKEN = "<TOKEN_GENERADO_EN_PASO_7>"

# Verifica que estén configuradas
Write-Host "VAULT_ADDR: $env:VAULT_ADDR"
Write-Host "TF_VAR_vault_token: $env:TF_VAR_vault_token"
```

**Configuración Persistente (recomendado para desarrollo)**:

**Opción 1: Variables de Usuario del Sistema (Windows)**:
```powershell
# Configurar VAULT_ADDR permanentemente
[System.Environment]::SetEnvironmentVariable("VAULT_ADDR", "http://127.0.0.1:8200", "User")

# Configurar el token (NOTA: El token puede expirar, considera usar configuración temporal)
[System.Environment]::SetEnvironmentVariable("TF_VAR_vault_token", "<TOKEN_GENERADO_EN_PASO_7>", "User")

# Recarga las variables en la sesión actual
$env:VAULT_ADDR = [System.Environment]::GetEnvironmentVariable("VAULT_ADDR", "User")
$env:TF_VAR_vault_token = [System.Environment]::GetEnvironmentVariable("TF_VAR_vault_token", "User")
```

**Opción 2: Archivo de Perfil de PowerShell**:
```powershell
# Edita tu perfil de PowerShell
notepad $PROFILE

# Agrega estas líneas (ajusta el token):
$env:VAULT_ADDR = "http://127.0.0.1:8200"
$env:TF_VAR_vault_token = "<TOKEN_GENERADO_EN_PASO_7>"

# Guarda y cierra. Las variables se cargarán en cada nueva sesión
```

**Opción 3: Script de Inicialización**:
Crea un archivo `init-vault.ps1` en el directorio del proyecto:
```powershell
# init-vault.ps1
$env:VAULT_ADDR = "http://127.0.0.1:8200"
$env:TF_VAR_vault_token = "<TOKEN_GENERADO_EN_PASO_7>"

Write-Host "Variables de Vault configuradas:" -ForegroundColor Green
Write-Host "  VAULT_ADDR: $env:VAULT_ADDR"
Write-Host "  TF_VAR_vault_token: [OCULTO]"
```

Luego, antes de usar Terraform, ejecuta:
```powershell
. .\init-vault.ps1
```

**Verificar la Configuración**:
```powershell
# Verifica que Vault esté accesible
vault status

# Verifica que puedas leer los secretos con el token configurado
vault kv get kv/spn/terraform-servicePrincipal
```

**⚠️ NOTA DE SEGURIDAD**: 
- No commitees archivos con tokens reales al repositorio
- Considera usar un archivo `.env` o `.vault-token` en `.gitignore`
- Rota los tokens periódicamente

### Paso 9: Verificar la Configuración Completa

Antes de usar Terraform, verifica que todo esté configurado correctamente:

```powershell
# 1. Verifica que Vault esté corriendo y desbloqueado
vault status
# Debe mostrar: Sealed: false

# 2. Verifica que estés autenticado
vault auth -method=token
# O simplemente verifica con:
vault token lookup

# 3. Verifica que el secrets engine esté habilitado
vault secrets list
# Debe mostrar: kv/ en la lista

# 4. Verifica que puedas leer los secretos
vault kv get kv/spn/terraform-servicePrincipal
# Debe mostrar: tenant_id, subscription_id, client_id, client_secret

# 5. Verifica que el token tenga los permisos correctos
vault token capabilities kv/data/spn/terraform-servicePrincipal
# Debe mostrar: read

# 6. Verifica las variables de entorno
Write-Host "VAULT_ADDR: $env:VAULT_ADDR"
Write-Host "TF_VAR_vault_token configurado: $($null -ne $env:TF_VAR_vault_token)"
```

**Si todos los pasos anteriores funcionan, estás listo para usar Terraform.**

### Paso 10: Integración con Terraform

Terraform está configurado para leer las credenciales de Azure desde Vault automáticamente. El archivo `Terraform/vault.tf` contiene:

```hcl
provider "vault" {
  address = "http://127.0.0.1:8200"
}

data "vault_kv_secret_v2" "mi_spn" {
  mount = "kv"
  name  = "spn/terraform-servicePrincipal"
}
```

Y `Terraform/providers.tf` usa estos datos:

```hcl
provider "azurerm" {
  client_id       = data.vault_kv_secret_v2.mi_spn.data["client_id"]
  client_secret   = data.vault_kv_secret_v2.mi_spn.data["client_secret"]
  tenant_id       = data.vault_kv_secret_v2.mi_spn.data["tenant_id"]
  subscription_id = data.vault_kv_secret_v2.mi_spn.data["subscription_id"]
}
```

**Para usar Terraform con Vault**:

1. **Asegúrate de que Vault esté corriendo y desbloqueado**:
   ```powershell
   vault status
   ```

2. **Configura las variables de entorno** (si no lo hiciste de forma persistente):
   ```powershell
   $env:VAULT_ADDR = "http://127.0.0.1:8200"
   $env:TF_VAR_vault_token = "<TU_TOKEN>"
   ```

3. **Navega al directorio de Terraform**:
   ```powershell
   cd ..\Terraform
   ```

4. **Inicializa Terraform**:
   ```powershell
   terraform init
   ```

5. **Verifica que Terraform pueda leer de Vault**:
   ```powershell
   terraform plan
   # Si hay errores de conexión a Vault, verifica:
   # - Vault está corriendo: vault status
   # - Variables de entorno configuradas
   # - Token válido y con permisos
   ```

**Troubleshooting de Integración Terraform-Vault**:

- **Error**: "Error reading KV secrets engine"
  - Verifica que el secrets engine esté habilitado: `vault secrets list`
  - Verifica que la ruta sea correcta: `kv/spn/terraform-servicePrincipal`

- **Error**: "permission denied"
  - Verifica que el token tenga permisos: `vault token capabilities kv/data/spn/terraform-servicePrincipal`
  - Verifica la política: `vault policy read terraform-policy`

- **Error**: "connection refused"
  - Verifica que Vault esté corriendo: `vault status`
  - Verifica `VAULT_ADDR`: `echo $env:VAULT_ADDR`

---

## 🔄 Operaciones Diarias

### Iniciar Vault

```powershell
# Navega al directorio Vault del proyecto
cd .\Vault

# Inicia el servidor de Vault
vault server -config .\config\vault.hcl
```

**Nota**: El servidor se ejecuta en primer plano. Para ejecutarlo en segundo plano en PowerShell:
```powershell
# Inicia Vault en segundo plano
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PWD\Vault'; vault server -config .\config\vault.hcl"
```

O usa un servicio de Windows o un administrador de procesos como `nssm` para ejecutarlo como servicio.

### Desbloquear Vault (después de reiniciar)

```powershell
$env:VAULT_ADDR = "http://127.0.0.1:8200"
vault operator unseal <UNSEAL_KEY_1>
vault operator unseal <UNSEAL_KEY_2>
vault operator unseal <UNSEAL_KEY_3>
```

### Verificar Estado

```powershell
# Verifica el estado general de Vault
vault status

# Salida esperada cuando está funcionando:
# Key             Value
# ---             -----
# Seal Type       shamir
# Initialized     true
# Sealed          false
# Total Shares    5
# Threshold       3
# Version         1.x.x
# Storage Type    file
# Cluster Name    vault-cluster-xxxxx
# Cluster ID      xxxxx-xxxxx-xxxxx
```

**Estados importantes**:
- **Initialized**: `true` = Vault ha sido inicializado
- **Sealed**: `false` = Vault está desbloqueado y operativo
- **Sealed**: `true` = Vault está bloqueado, necesitas desbloquearlo

**Comandos adicionales de verificación**:
```powershell
# Ver información del token actual
vault token lookup

# Ver tus políticas asignadas
vault token lookup -format=json | ConvertFrom-Json | Select-Object -ExpandProperty data | Select-Object -ExpandProperty policies

# Verificar conectividad
vault auth -method=token
```

### Autenticarse

```powershell
vault login <TOKEN>
```

### Leer Secretos

```powershell
# Leer las credenciales de Azure
vault kv get kv/azure

# Leer un campo específico
vault kv get -field=tenant_id kv/azure
```

### Actualizar Secretos

```powershell
vault kv put kv/azure tenant_id="<NUEVO_TENANT_ID>" subscription_id="<NUEVO_SUBSCRIPTION_ID>"
```

### Sellar Vault (cerrar)

```powershell
vault operator seal
```

---

## 🔐 Seguridad y Mejores Prácticas

### Desarrollo Local

1. ✅ Usa `vault.hcl.example` como base y ajusta según necesidad
2. ✅ Mantén `tls_disable = 1` solo en desarrollo
3. ✅ No commitees `init.txt` o archivos con credenciales reales
4. ✅ Usa tokens con permisos limitados en lugar del root token

### Producción

1. **TLS/SSL**: Configura certificados TLS apropiados
   ```hcl
   listener "tcp" {
     address       = "0.0.0.0:8200"
     tls_cert_file = "/path/to/cert.pem"
     tls_key_file  = "/path/to/key.pem"
   }
   ```

2. **Auto-unseal**: Usa Azure Key Vault, AWS KMS, o HSM para auto-unseal
   ```hcl
   seal "azurekeyvault" {
     tenant_id     = "<TENANT_ID>"
     vault_name    = "<KEY_VAULT_NAME>"
     key_name      = "<KEY_NAME>"
   }
   ```

3. **Backend Remoto**: Usa Azure Storage, AWS S3, o Consul en lugar de filesystem
   ```hcl
   storage "azure" {
     accountName = "<STORAGE_ACCOUNT>"
     accountKey  = "<ACCOUNT_KEY>"
     container   = "vault"
   }
   ```

4. **Políticas Granulares**: Crea políticas específicas para cada aplicación/usuario
5. **Auditoría**: Habilita audit logs
6. **Rotación**: Rota tokens y unseal keys regularmente
7. **Backup**: Implementa backups automatizados del directorio de datos

---

## 🐛 Solución de Problemas

### Vault no inicia

**Error**: "address already in use"
```powershell
# Verifica qué proceso está usando el puerto 8200
netstat -ano | findstr :8200

# Identifica el PID y termínalo si es necesario
taskkill /PID <PID> /F

# O cambia el puerto en vault.hcl
# listener "tcp" {
#   address = "127.0.0.1:8201"  # Cambia a otro puerto
# }
```

**Error**: "permission denied" en la ruta de storage
```powershell
# Verifica que el directorio exista
Test-Path "C:\Vault"

# Si no existe, créalo
New-Item -ItemType Directory -Path "C:\Vault" -Force

# Verifica permisos (ejecuta como Administrador si es necesario)
icacls "C:\Vault" /grant "$env:USERNAME:(OI)(CI)F"
```

**Error**: "failed to lock memory"
- **Causa**: Problema con mlock en Windows
- **Solución**: Asegúrate de que `disable_mlock = true` esté en `vault.hcl`

**Error**: "no such file or directory" en la ruta de configuración
```powershell
# Verifica que el archivo de configuración exista
Test-Path .\config\vault.hcl

# Verifica que estés en el directorio correcto
Get-Location
```

### Vault está sellado (sealed)

**Síntoma**: `vault status` muestra `Sealed: true`

**Solución**: Desbloquea con las Unseal Keys
```powershell
# Configura VAULT_ADDR si no está configurado
$env:VAULT_ADDR = "http://127.0.0.1:8200"

# Desbloquea con 3 de las 5 llaves (threshold)
vault operator unseal <UNSEAL_KEY_1>
vault operator unseal <UNSEAL_KEY_2>
vault operator unseal <UNSEAL_KEY_3>

# Verifica el estado
vault status
# Debe mostrar: Sealed: false
```

**Si perdiste las Unseal Keys**:
- Si tienes el root token, puedes regenerar las keys: `vault operator rekey`
- Si no tienes ni las keys ni el root token, **no hay recuperación posible** (por diseño de seguridad)
- Necesitarás reinicializar Vault (esto borrará todos los datos)

**⚠️ Reinicializar Vault (BORRA TODOS LOS DATOS)**:
```powershell
# SOLO si perdiste las keys y el root token
# 1. Detén Vault
# 2. Elimina el directorio de datos
Remove-Item -Recurse -Force "C:\Vault"  # O la ruta que configuraste

# 3. Inicia Vault de nuevo
vault server -config .\config\vault.hcl

# 4. En otra terminal, reinicializa
$env:VAULT_ADDR = "http://127.0.0.1:8200"
vault operator init

# 5. Guarda las nuevas keys y token
# 6. Sigue los pasos de configuración desde el Paso 3
```

### No puedo leer secretos

**Error**: "permission denied"
```powershell
# 1. Verifica que estés autenticado
vault token lookup

# 2. Verifica los permisos del token
vault token capabilities kv/data/spn/terraform-servicePrincipal

# 3. Verifica la política asignada
vault policy read terraform-policy

# 4. Verifica que el token tenga la política correcta
vault token lookup -format=json | ConvertFrom-Json | Select-Object -ExpandProperty data | Select-Object -ExpandProperty policies
```

**Error**: "no secret found"
```powershell
# Verifica que el secreto exista
vault kv list kv/spn/

# Verifica la ruta exacta
vault kv get kv/spn/terraform-servicePrincipal

# Si no existe, créalo (Paso 6)
```

**Error**: "invalid path"
- Verifica que el secrets engine esté habilitado: `vault secrets list`
- Verifica que uses la ruta correcta: `kv/spn/terraform-servicePrincipal` (no `kv/data/spn/...` en el comando `vault kv`)

### Terraform no puede conectarse a Vault

**Error**: "connection refused" o "dial tcp"
```powershell
# 1. Verifica que Vault esté corriendo
vault status
# Si falla, inicia Vault: vault server -config .\config\vault.hcl

# 2. Verifica VAULT_ADDR
echo $env:VAULT_ADDR
# Debe ser: http://127.0.0.1:8200

# 3. Verifica TF_VAR_vault_token o VAULT_TOKEN
echo $env:TF_VAR_vault_token
echo $env:VAULT_TOKEN

# 4. Prueba la conexión manualmente
vault kv get kv/spn/terraform-servicePrincipal
```

**Error**: "Error reading KV secrets engine"
```powershell
# Verifica que el secrets engine esté habilitado
vault secrets list
# Debe mostrar: kv/

# Si no está, habilítalo:
vault secrets enable -path=kv kv-v2
```

**Error**: "permission denied" en Terraform
```powershell
# Verifica que el token tenga permisos
vault token capabilities kv/data/spn/terraform-servicePrincipal
# Debe mostrar: read

# Si no tiene permisos, crea/actualiza la política (Paso 7)
```

### Problemas con Variables de Entorno

**Las variables no persisten entre sesiones**:
- Usa configuración persistente (Paso 8, Opción 1 o 2)
- O crea un script de inicialización

**PowerShell no reconoce las variables**:
```powershell
# Verifica que las variables estén configuradas
Get-ChildItem Env: | Where-Object Name -like "*VAULT*"
Get-ChildItem Env: | Where-Object Name -like "*TF_VAR*"

# Recarga el perfil si usaste $PROFILE
. $PROFILE
```

### Problemas de Autenticación

**Error**: "missing client token"
```powershell
# Autentícate con el token
vault login <TU_TOKEN>

# O configura la variable de entorno
$env:VAULT_TOKEN = "<TU_TOKEN>"
```

**Error**: "token not found" o "invalid token"
- El token puede haber expirado
- Crea un nuevo token: `vault token create -policy=terraform-policy`
- Actualiza `TF_VAR_vault_token` con el nuevo token

### Problemas con el Secrets Engine KV v2

**Error al escribir secretos**:
```powershell
# Verifica que uses kv-v2 (no kv-v1)
vault secrets list -detailed

# La ruta debe mostrar: kv/ (tipo: kv, versión: 2)

# Si está en versión 1, deshabilítalo y habilita v2:
vault secrets disable kv
vault secrets enable -path=kv -version=2 kv
```

**Confusión entre rutas de API y comandos kv**:
- **Comando `vault kv`**: Usa `kv/spn/terraform-servicePrincipal`
- **API/Políticas**: Usa `kv/data/spn/terraform-servicePrincipal` (con `/data/`)
- **Metadata**: Usa `kv/metadata/spn/terraform-servicePrincipal`

---

## 📋 Comandos de Referencia Rápida

### Comandos Básicos
```powershell
# Estado y autenticación
vault status                    # Ver estado de Vault
vault login <token>            # Autenticarse
vault token lookup             # Ver información del token actual

# Secrets Engine
vault secrets list             # Listar secrets engines habilitados
vault secrets enable -path=kv kv-v2  # Habilitar KV v2

# Operaciones con secretos
vault kv put kv/ruta key=value  # Escribir secreto
vault kv get kv/ruta           # Leer secreto
vault kv list kv/              # Listar secretos
vault kv delete kv/ruta        # Eliminar secreto

# Políticas
vault policy list              # Listar políticas
vault policy read <nombre>     # Leer política
vault policy write <nombre> <archivo>  # Crear/actualizar política

# Tokens
vault token create -policy=<nombre>  # Crear token
vault token revoke <token>     # Revocar token

# Operaciones de sistema
vault operator unseal <key>    # Desbloquear Vault
vault operator seal            # Bloquear Vault
vault operator init            # Inicializar Vault (solo primera vez)
```

### Variables de Entorno
```powershell
# Configurar (temporal)
$env:VAULT_ADDR = "http://127.0.0.1:8200"
$env:TF_VAR_vault_token = "<token>"

# Verificar
echo $env:VAULT_ADDR
echo $env:TF_VAR_vault_token
```

## 📚 Referencias

### Documentación Oficial
- [Documentación oficial de HashiCorp Vault](https://developer.hashicorp.com/vault/docs)
- [Guía de configuración de Vault](https://developer.hashicorp.com/vault/docs/configuration)
- [Secrets Engines](https://developer.hashicorp.com/vault/docs/secrets)
- [Políticas de Vault](https://developer.hashicorp.com/vault/docs/concepts/policies)
- [KV Secrets Engine v2](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2)

### Integración con Terraform
- [Proveedor Vault de Terraform](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)
- [Data Source: vault_kv_secret_v2](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/data-sources/kv_secret_v2)

### Recursos Adicionales
- [HashiCorp Learn - Vault](https://learn.hashicorp.com/vault)
- [Vault Best Practices](https://developer.hashicorp.com/vault/docs/best-practices)
- [Vault Security Hardening](https://developer.hashicorp.com/vault/docs/security)

### Comunidad y Soporte
- [HashiCorp Community Forum](https://discuss.hashicorp.com/c/vault)
- [Vault GitHub](https://github.com/hashicorp/vault)
- [Stack Overflow - HashiCorp Vault](https://stackoverflow.com/questions/tagged/vault)

---

## 📝 Notas Adicionales

- Este setup es para **desarrollo y demostración local**
- Para producción, implementa las medidas de seguridad mencionadas
- Considera usar Vault en modo HA (High Availability) con múltiples nodos
- El archivo `init.txt` en este repositorio es solo un ejemplo y **NO debe usarse en producción**

---

**Última actualización**: 2026 (HashiTalk España 2026)
