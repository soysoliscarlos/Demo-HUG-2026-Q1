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
Unseal Key 1: ZAC2YOht56WrEk3b9LIQMLf84d1UfO2j8Sd/6HRPI2MC
Unseal Key 2: <UNSEAL_KEY_1>
Unseal Key 3: <UNSEAL_KEY_2>
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

## 🚀 Proceso de Configuración de HashiCorp Vault

### Prerrequisitos

1. **Instalar HashiCorp Vault**:
   ```powershell
   # Opción 1: Usando Chocolatey
   choco install vault
   
   # Opción 2: Descargar manualmente desde
   # https://developer.hashicorp.com/vault/downloads
   
   # Verificar instalación
   vault version
   ```

2. **Verificar que el puerto 8200 esté disponible**:
   ```powershell
   netstat -an | findstr :8200
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

Almacena las credenciales de Azure que Terraform consumirá:

```powershell
# Almacena las credenciales de Azure en kv/azure
vault kv put kv/azure \
  tenant_id="<TU_TENANT_ID>" \
  subscription_id="<TU_SUBSCRIPTION_ID>" \
  client_id="<TU_CLIENT_ID>" \
  client_secret="<TU_CLIENT_SECRET>"
```

**Nota**: En PowerShell, usa comillas simples o dobles escapadas:
```powershell
vault kv put kv/azure `
  tenant_id="<TU_TENANT_ID>" `
  subscription_id="<TU_SUBSCRIPTION_ID>" `
  client_id="<TU_CLIENT_ID>" `
  client_secret="<TU_CLIENT_SECRET>"
```

O usa un archivo JSON:
```powershell
# Crea un archivo temporal con las credenciales
@{
    tenant_id = "<TU_TENANT_ID>"
    subscription_id = "<TU_SUBSCRIPTION_ID>"
    client_id = "<TU_CLIENT_ID>"
    client_secret = "<TU_CLIENT_SECRET>"
} | ConvertTo-Json | vault kv put kv/azure -
```

Verifica que se guardaron correctamente:
```powershell
vault kv get kv/azure
```

### Paso 7: Crear un Token para Terraform (Recomendado)

En lugar de usar el root token, crea un token con permisos limitados:

```powershell
# Crea una política que permita leer solo kv/azure
vault policy write terraform-policy - <<EOF
path "kv/data/azure" {
  capabilities = ["read"]
}

path "kv/metadata/azure" {
  capabilities = ["read", "list"]
}
EOF

# Crea un token con esta política
vault token create -policy=terraform-policy -ttl=24h
```

Guarda el token generado. Este es el token que usarás con Terraform.

### Paso 8: Configurar Variables de Entorno para Terraform

```powershell
# Exporta el token de Vault para Terraform
$env:TF_VAR_vault_token = "<TOKEN_GENERADO_EN_PASO_7>"

# O si usas el root token (NO RECOMENDADO):
# $env:TF_VAR_vault_token = "<ROOT_TOKEN>"

# Verifica que esté configurado
echo $env:TF_VAR_vault_token
```

---

## 🔄 Operaciones Diarias

### Iniciar Vault

```powershell
cd .\DemoHashiTalkEspana2026\Vault
vault server -config .\config\vault.hcl
```

### Desbloquear Vault (después de reiniciar)

```powershell
$env:VAULT_ADDR = "http://127.0.0.1:8200"
vault operator unseal <UNSEAL_KEY_1>
vault operator unseal <UNSEAL_KEY_2>
vault operator unseal <UNSEAL_KEY_3>
```

### Verificar Estado

```powershell
vault status
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

- **Error**: "address already in use"
  - **Solución**: Verifica que el puerto 8200 no esté en uso: `netstat -an | findstr :8200`
  - Cambia el puerto en `vault.hcl` si es necesario

- **Error**: "permission denied" en la ruta de storage
  - **Solución**: Verifica permisos del directorio o cambia la ruta a una ubicación accesible

### Vault está sellado (sealed)

- **Síntoma**: `vault status` muestra `Sealed: true`
- **Solución**: Desbloquea con las Unseal Keys (ver Paso 3)

### No puedo leer secretos

- **Error**: "permission denied"
  - **Solución**: Verifica que el token tenga los permisos correctos
  - Revisa las políticas: `vault policy read terraform-policy`

### Terraform no puede conectarse a Vault

- **Error**: "connection refused" o "dial tcp"
  - **Solución**: 
    1. Verifica que Vault esté corriendo: `vault status`
    2. Verifica `VAULT_ADDR`: `echo $env:VAULT_ADDR`
    3. Verifica `TF_VAR_vault_token`: `echo $env:TF_VAR_vault_token`

---

## 📚 Referencias

- [Documentación oficial de HashiCorp Vault](https://developer.hashicorp.com/vault/docs)
- [Guía de configuración de Vault](https://developer.hashicorp.com/vault/docs/configuration)
- [Secrets Engines](https://developer.hashicorp.com/vault/docs/secrets)
- [Políticas de Vault](https://developer.hashicorp.com/vault/docs/concepts/policies)
- [Proveedor Vault de Terraform](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)

---

## 📝 Notas Adicionales

- Este setup es para **desarrollo y demostración local**
- Para producción, implementa las medidas de seguridad mencionadas
- Considera usar Vault en modo HA (High Availability) con múltiples nodos
- El archivo `init.txt` en este repositorio es solo un ejemplo y **NO debe usarse en producción**

---

**Última actualización**: 2026 (HashiTalk España 2026)
