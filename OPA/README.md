# Guía Completa de OPA para Validación de Políticas Terraform

Esta guía explica cómo instalar, configurar y usar Open Policy Agent (OPA) con la política `deny_public_internet.rego` para validar que los recursos de Terraform no tengan acceso público habilitado.

## 📋 Tabla de Contenidos

1. [Instalación de OPA desde Cero](#instalación-de-opa-desde-cero)
2. [Configuración Inicial](#configuración-inicial)
3. [Prerrequisitos](#prerrequisitos)
4. [Documentación del Archivo Rego](#documentación-del-archivo-rego)
5. [Documentación del Script PowerShell](#documentación-del-script-powershell)
6. [Métodos de Evaluación](#métodos-de-evaluación)
7. [Qué Valida la Política](#qué-valida-la-política)
8. [Integración con CI/CD](#integración-con-cicd)
9. [Solución de Problemas](#solución-de-problemas)

---

## Instalación de OPA desde Cero

### ¿Qué es OPA?

Open Policy Agent (OPA) es un motor de políticas de código abierto que unifica la aplicación de políticas en toda la pila tecnológica. OPA permite definir políticas como código y evaluarlas contra datos estructurados (como planes de Terraform).

### Requisitos del Sistema

- **Sistema Operativo**: Windows, Linux, o macOS
- **Arquitectura**: x86_64 (amd64) o ARM64
- **Permisos**: Permisos de escritura para instalar y ejecutar binarios
- **Terraform**: Versión 0.12 o superior (para generar planes en formato JSON)

### Método 1: Instalación en Windows

#### Opción A: Descarga Manual (Recomendado)

1. **Descargar OPA CLI**:
   - Visita: https://www.openpolicyagent.org/docs/latest/#running-opa
   - O descarga directamente desde: https://github.com/open-policy-agent/opa/releases
   - Busca la versión más reciente (ej: `opa_windows_amd64.exe`)
   - Descarga el archivo ejecutable

2. **Instalar OPA**:
   ```powershell
   # Crear directorio para OPA (opcional, pero recomendado)
   New-Item -ItemType Directory -Force -Path "$env:ProgramFiles\OPA"
   
   # Mover el ejecutable descargado al directorio
   # Renombrar el archivo descargado a 'opa.exe'
   Move-Item -Path ".\opa_windows_amd64.exe" -Destination "$env:ProgramFiles\OPA\opa.exe"
   ```

3. **Agregar OPA al PATH**:
   ```powershell
   # Agregar al PATH del usuario actual
   $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
   $newPath = "$env:ProgramFiles\OPA;$currentPath"
   [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
   
   # O agregar al PATH del sistema (requiere permisos de administrador)
   # $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
   # $newPath = "$env:ProgramFiles\OPA;$currentPath"
   # [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
   ```

4. **Verificar Instalación**:
   ```powershell
   # Cerrar y reabrir PowerShell para que los cambios en PATH surtan efecto
   # Luego verificar:
   opa version
   ```
   
   Deberías ver algo como:
   ```
   Version: 0.62.0
   Build Commit: abc123...
   Build Timestamp: 2024-01-01T00:00:00Z
   Build Hostname: build-host
   ```

#### Opción B: Usando Chocolatey

Si tienes Chocolatey instalado:

```powershell
# Instalar OPA usando Chocolatey
choco install opa

# Verificar instalación
opa version
```

#### Opción C: Usando Scoop

Si tienes Scoop instalado:

```powershell
# Agregar bucket de extras (si no está agregado)
scoop bucket add extras

# Instalar OPA
scoop install opa

# Verificar instalación
opa version
```

#### Opción D: Usando winget (Windows Package Manager)

```powershell
# Instalar OPA usando winget
winget install OpenPolicyAgent.OPA

# Verificar instalación
opa version
```

### Método 2: Instalación en Linux

#### Opción A: Descarga Manual

```bash
# Descargar la última versión
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64

# Hacer ejecutable
chmod +x opa

# Mover a un directorio en PATH
sudo mv opa /usr/local/bin/

# Verificar instalación
opa version
```

#### Opción B: Usando el Repositorio de Debian/Ubuntu

```bash
# Agregar la clave GPG
curl -fsSL https://download.opensuse.org/repositories/home:/pabluk:/OPA/Debian_12/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/opa-archive-keyring.gpg

# Agregar el repositorio
echo "deb [signed-by=/usr/share/keyrings/opa-archive-keyring.gpg] https://download.opensuse.org/repositories/home:/pabluk:/OPA/Debian_12/ /" | sudo tee /etc/apt/sources.list.d/opa.list

# Actualizar e instalar
sudo apt update
sudo apt install opa

# Verificar instalación
opa version
```

#### Opción C: Usando el Repositorio de Red Hat/CentOS/Fedora

```bash
# Agregar el repositorio
sudo tee /etc/yum.repos.d/opa.repo <<EOF
[opa]
name=OPA
baseurl=https://download.opensuse.org/repositories/home:/pabluk:/OPA/CentOS_8/
enabled=1
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/home:/pabluk:/OPA/CentOS_8/repodata/repomd.xml.key
EOF

# Instalar
sudo yum install opa

# Verificar instalación
opa version
```

### Método 3: Instalación en macOS

#### Opción A: Usando Homebrew (Recomendado)

```bash
# Instalar OPA
brew install opa

# Verificar instalación
opa version
```

#### Opción B: Descarga Manual

```bash
# Descargar la última versión
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_darwin_amd64

# Hacer ejecutable
chmod +x opa

# Mover a un directorio en PATH
sudo mv opa /usr/local/bin/

# Verificar instalación
opa version
```

### Método 4: Instalación usando Docker

Si prefieres usar OPA en un contenedor Docker:

```powershell
# En Windows PowerShell
docker run -it --rm openpolicyagent/opa version

# Para evaluar políticas, monta los archivos como volúmenes
docker run -it --rm `
  -v ${PWD}:/workspace `
  -w /workspace `
  openpolicyagent/opa eval `
    --input /workspace/../Terraform/tfplan.json `
    --data /workspace/deny_public_internet.rego `
    --format pretty `
    "data.terraform.deny_public_internet.deny"
```

### Verificación de la Instalación

Después de instalar OPA, verifica que funciona correctamente:

```powershell
# Verificar versión
opa version

# Probar con una política simple
echo 'package test
deny contains msg if {
    input.message == "hello"
    msg := "found hello"
}' > test.rego

echo '{"message": "hello"}' | opa eval --input - --data test.rego --format pretty "data.test.deny"

# Deberías ver: ["found hello"]

# Limpiar
Remove-Item test.rego
```

### Solución de Problemas de Instalación

#### Error: "opa: command not found" o "opa no se reconoce como comando"

**Causa**: OPA no está en el PATH del sistema.

**Solución**:
1. Verifica que el ejecutable existe:
   ```powershell
   # Windows
   Test-Path "$env:ProgramFiles\OPA\opa.exe"
   
   # Linux/macOS
   which opa
   ```

2. Verifica el PATH:
   ```powershell
   # Windows PowerShell
   $env:Path -split ';' | Select-String -Pattern "OPA"
   
   # Linux/macOS
   echo $PATH | grep -i opa
   ```

3. Si OPA no está en el PATH:
   - **Windows**: Agrega manualmente el directorio a las variables de entorno del sistema
   - **Linux/macOS**: Asegúrate de que el binario esté en `/usr/local/bin` o agrega el directorio al PATH en `~/.bashrc` o `~/.zshrc`

4. Reinicia la terminal después de modificar el PATH

#### Error: "Permission denied" (Linux/macOS)

**Causa**: El archivo no tiene permisos de ejecución o no tienes permisos para escribir en el directorio.

**Solución**:
```bash
# Dar permisos de ejecución
chmod +x opa

# O instalar en un directorio donde tengas permisos
mkdir -p ~/bin
mv opa ~/bin/
export PATH="$HOME/bin:$PATH"
```

#### Error: "The system cannot find the file specified" (Windows)

**Causa**: El archivo no existe o la ruta es incorrecta.

**Solución**:
1. Verifica que descargaste el archivo correcto para tu arquitectura (amd64 vs arm64)
2. Verifica que el archivo se renombró correctamente a `opa.exe`
3. Verifica que el directorio existe y el archivo está ahí

---

## Configuración Inicial

### Estructura de Directorios

Asegúrate de tener la siguiente estructura de directorios:

```
Demo-HUG-2026-Q1/
├── OPA/
│   ├── README.md                    # Este archivo
│   ├── deny_public_internet.rego    # Política OPA
│   └── evaluar_politica.ps1         # Script de evaluación
└── Terraform/
    ├── main.tf
    ├── storage.tf
    ├── key_vault.tf
    └── tfplan.json                  # Plan JSON (generado)
```

### Configuración del Entorno

1. **Navegar al directorio OPA**:
   ```powershell
   cd OPA
   ```

2. **Verificar que los archivos existen**:
   ```powershell
   Test-Path "deny_public_internet.rego"
   Test-Path "evaluar_politica.ps1"
   ```

3. **Verificar permisos de ejecución** (Linux/macOS):
   ```bash
   chmod +x evaluar_politica.ps1
   ```

### Configuración de PowerShell (Windows)

Si estás usando Windows, asegúrate de que PowerShell puede ejecutar scripts:

```powershell
# Verificar política de ejecución
Get-ExecutionPolicy

# Si es "Restricted", cambiar a "RemoteSigned" o "Bypass" (solo para desarrollo)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Prerrequisitos

Antes de usar la política OPA, asegúrate de tener:

1. **OPA CLI instalado y configurado**: Ver sección [Instalación de OPA desde Cero](#instalación-de-opa-desde-cero)
   ```powershell
   # Verificar instalación
   opa version
   ```

2. **Terraform instalado**: Versión 0.12 o superior
   ```powershell
   terraform version
   ```

3. **Plan de Terraform en formato JSON**: 
   ```powershell
   # Navegar al directorio Terraform
   cd ..\Terraform
   
   # Generar plan binario
   terraform init
   terraform plan -out=tfplan.bin
   
   # Convertir a JSON
   terraform show -json tfplan.bin > tfplan.json
   
   # Volver al directorio OPA
   cd ..\OPA
   ```

4. **Archivos de política y script**:
   - `deny_public_internet.rego` debe estar en el directorio `OPA`
   - `evaluar_politica.ps1` debe estar en el directorio `OPA`

---

## Documentación del Archivo Rego

### `deny_public_internet.rego`

Este archivo contiene una política de OPA escrita en Rego que valida que ningún recurso en un plan de Terraform tenga acceso público a Internet habilitado. La política analiza los cambios de recursos en el plan (formato `tfplan/v2`) y emite mensajes en el conjunto `deny` para cada violación encontrada.

#### Estructura del Archivo

**Paquete y Configuración (líneas 1-3)**
```rego
package terraform.deny_public_internet
import rego.v1
```
- Define el paquete de la política con el namespace `terraform.deny_public_internet`
- Importa la sintaxis moderna de Rego (`rego.v1`)

**Reglas de Denegación por Tipo de Recurso**

La política contiene múltiples reglas `deny` que se evalúan independientemente. Cada regla verifica un tipo específico de recurso o condición:

1. **Azure Storage Account - Blob Public Access (líneas 14-26)**
   - Verifica que `allow_blob_public_access` no sea `true`
   - Mensaje: `"Storage account {name} has allow_blob_public_access = true"`

2. **Azure Storage Account - Public Network Access (String) (líneas 28-40)**
   - Verifica que `public_network_access` (string) sea `"Disabled"` o vacío
   - Convierte a minúsculas para comparación case-insensitive
   - Mensaje: `"Storage account {name} has public_network_access = {value}"`

3. **Azure Storage Account - Public Network Access (Boolean) (líneas 42-54)**
   - Verifica que `public_network_access_enabled` (boolean) sea `false`
   - Usa función helper `is_boolean()` para validar el tipo
   - Mensaje: `"Storage account {name} has public_network_access_enabled = true (debe ser false)"`

4. **Azure Key Vault - Public Network Access (String) (líneas 56-69)**
   - Verifica que `public_network_access` (string) sea `"Disabled"` o vacío
   - Mensaje: `"Key Vault {name} has public network access enabled"`

5. **Azure Key Vault - Public Network Access (Boolean) (líneas 71-83)**
   - Verifica que `public_network_access_enabled` (boolean) sea `false`
   - Mensaje: `"Key Vault {name} has public_network_access_enabled = true (debe ser false)"`

6. **Azure AI Services - Public Network Access (String) (líneas 117-129)**
   - Verifica que `public_network_access` (string) sea `"Disabled"` o vacío
   - Mensaje: `"AI service {name} has public_network_access = {value}"`

7. **Azure AI Services - Public Network Access (Boolean) (líneas 131-142)**
   - Verifica que `public_network_access_enabled` (boolean) sea `false`
   - Mensaje: `"AI service {name} has public network access enabled"`

8. **Azure AI Foundry - Public Network Access (String) (líneas 144-157)**
   - Verifica que `public_network_access` (string) sea `"Disabled"` o vacío
   - Mensaje: `"AI Foundry {name} has public_network_access = {value}"`

9. **Azure AI Foundry - Public Network Access (Boolean) (líneas 159-170)**
   - Verifica que `public_network_access_enabled` (boolean) sea `false`
   - Mensaje: `"AI Foundry {name} has public network access enabled"`

10. **Azure AI Foundry Project - Public Network Access (String) (líneas 172-183)**
    - Verifica que `public_network_access` (string) sea `"Disabled"` o vacío
    - Mensaje: `"AI Foundry project {name} has public network access enabled"`

11. **Azure AI Foundry Project - Public Network Access (Boolean) (líneas 185-196)**
    - Verifica que `public_network_access_enabled` (boolean) sea `false`
    - Mensaje: `"AI Foundry project {name} has public network access enabled"`

12. **Catch-all para Recursos Genéricos - String (líneas 198-217)**
    - Verifica cualquier recurso con `public_network_access` (string) que no sea `"Disabled"`
    - Excluye tipos específicos que ya tienen reglas dedicadas para evitar duplicados
    - Mensaje: `"Resource {name} ({type}) has public_network_access = {value}"`

13. **Catch-all para Recursos Genéricos - Boolean (líneas 219-234)**
    - Verifica cualquier recurso con `public_network_access_enabled = true`
    - Excluye tipos específicos que ya tienen reglas dedicadas
    - Mensaje: `"Resource {name} ({type}) has public_network_access_enabled = true"`

14. **Network Security Group - Outbound Rules (líneas 236-252)**
    - Verifica reglas de salida (outbound) que permiten tráfico a Internet
    - Usa funciones helper `get_destination()` e `is_open_internet()` para identificar destinos públicos
    - Mensaje: `"Network Security Group {name} has an outbound rule '{rule_name}' allowing traffic to {destination}"`

#### Funciones Helper (líneas 268-358)

**`get_first(list)` (líneas 272-284)**
- Extrae el primer elemento de una lista o retorna un objeto vacío si la lista es null o vacía
- Útil para acceder a elementos de arrays que pueden estar vacíos

**`is_array(val)` (líneas 287-289)**
- Verifica si un valor es un array usando pattern matching de Rego

**`arrayify(val)` (líneas 292-299)**
- Convierte un valor a lista; si ya es una lista, la retorna tal cual
- Si no es una lista, retorna una lista vacía
- Útil para normalizar valores que pueden ser arrays o null

**`get_destination(rule)` (líneas 302-322)**
- Determina el prefijo de dirección de destino para una regla de NSG
- Prioriza `destination_address_prefixes` (array) sobre `destination_address_prefix` (string)
- Retorna el primer elemento del array si existe, o el string si el array está vacío/null

**`is_open_internet(prefix)` (líneas 325-338)**
- Verifica si un prefijo de dirección representa acceso abierto a Internet
- Considera válidos: `"*"`, `"internet"`, `"0.0.0.0/0"` (case-insensitive)
- Usa `lower()` para normalizar la comparación

**`exists_deny_outbound(rules)` (líneas 341-348)**
- Verifica si existe al menos una regla de salida que deniega tráfico a Internet
- Actualmente no se usa (regla comentada), pero disponible para futuras validaciones

**`is_boolean(x)` (líneas 351-357)**
- Verifica si un valor es de tipo booleano
- Retorna true si el valor es `true` o `false`

#### Regla de Violaciones (líneas 369-371)

```rego
violations if {
    count(deny) > 0
}
```

- Esta regla booleana se define solo cuando hay violaciones
- Útil para usar con `--fail-defined` en OPA CLI para que el comando salga con código de error no-cero si existen violaciones
- Ejemplo de uso: `opa eval --fail-defined "data.terraform.deny_public_internet.violations"`

#### Reglas Comentadas

- **Key Vault Network ACLs (líneas 85-115)**: Reglas para validar `network_acls.default_action` y `network_acls.bypass` están deshabilitadas
- **NSG Outbound Deny Rule Check (líneas 254-266)**: Regla para verificar que exista una regla de denegación de salida está deshabilitada

---

## Documentación del Script PowerShell

### `evaluar_politica.ps1`

Script de PowerShell que automatiza la evaluación de la política OPA, proporcionando una interfaz amigable con validaciones, mensajes de error claros y formato de salida coloreado.

#### Parámetros del Script

```powershell
param(
    [string]$PlanFile = "..\Terraform\tfplan.json",      # Ruta al archivo de plan JSON
    [string]$PolicyFile = "deny_public_internet.rego",   # Ruta al archivo de política Rego
    [switch]$FailOnViolation = $false                   # Si es true, el script sale con error si hay violaciones
)
```

**Parámetros:**
- `$PlanFile`: Ruta relativa o absoluta al archivo `tfplan.json` generado por Terraform. Por defecto: `"..\Terraform\tfplan.json"`
- `$PolicyFile`: Ruta al archivo de política Rego. Por defecto: `"deny_public_internet.rego"` (en el directorio actual)
- `$FailOnViolation`: Switch booleano. Si está presente, el script termina con código de salida 1 si se encuentran violaciones (útil para CI/CD)

#### Flujo de Ejecución

**1. Encabezado y Presentación (líneas 10-14)**
- Muestra un encabezado formateado con colores
- Indica el nombre de la política que se está evaluando

**2. Verificación de OPA (líneas 16-24)**
```powershell
$opaVersion = opa version 2>&1
```
- Intenta ejecutar `opa version` para verificar que OPA está instalado
- Captura tanto stdout como stderr (`2>&1`)
- Si falla, muestra mensaje de error con enlace de descarga y sale con código 1

**3. Validación de Archivos (líneas 26-44)**
- Verifica que `$PlanFile` exista usando `Test-Path`
- Si no existe, muestra instrucciones para generarlo y sale con código 1
- Verifica que `$PolicyFile` exista
- Muestra mensajes de confirmación en verde para archivos encontrados

**4. Ejecución de Evaluación (líneas 46-88)**
```powershell
$query = "data.terraform.deny_public_internet.deny"
$argsList = @('eval', '--input', $PlanFile, '--data', $PolicyFile, '--format', 'pretty', $query)
$output = & opa @argsList 2>&1
```

- Construye la consulta OPA: `data.terraform.deny_public_internet.deny`
- Prepara argumentos para OPA CLI con formato legible (`--format pretty`)
- Ejecuta OPA capturando toda la salida

**5. Procesamiento de Resultados (líneas 57-88)**

**Si no hay violaciones:**
- Detecta patrones `[]` o `undefined` en la salida
- Muestra mensaje de éxito en verde
- Sale con código 0

**Si hay violaciones:**
- Muestra encabezado de violaciones en rojo
- Extrae mensajes de violación usando expresiones regulares:
  ```powershell
  $violations = $output | Select-String -Pattern '"(.*)"' | ForEach-Object {
      $_.Matches.Groups[1].Value
  }
  ```
- Muestra cada violación como una lista con viñetas en rojo
- Si `$FailOnViolation` está activado, sale con código 1; de lo contrario, muestra advertencia y sale con código 0

**6. Manejo de Errores (líneas 89-92)**
- Captura excepciones durante la ejecución de OPA
- Muestra mensaje de error en rojo
- Sale con código 1

#### Códigos de Salida

- `0`: Éxito (no hay violaciones o violaciones ignoradas)
- `1`: Error (OPA no encontrado, archivos faltantes, error de ejecución, o violaciones si `$FailOnViolation` está activado)

#### Ejemplos de Uso

**Uso básico (desde la carpeta OPA):**
```powershell
.\evaluar_politica.ps1
```

**Especificar archivos personalizados:**
```powershell
.\evaluar_politica.ps1 -PlanFile "C:\ruta\custom\tfplan.json" -PolicyFile "mi_politica.rego"
```

**Para CI/CD (falla si hay violaciones):**
```powershell
.\evaluar_politica.ps1 -FailOnViolation
```

**Combinación completa:**
```powershell
.\evaluar_politica.ps1 -PlanFile "..\Terraform\tfplan.json" -PolicyFile "deny_public_internet.rego" -FailOnViolation
```

---

## Métodos de Evaluación

### Método 1: Usando el Script PowerShell (Recomendado)

El script `evaluar_politica.ps1` proporciona una interfaz amigable con validaciones automáticas y formato de salida coloreado.

```powershell
# Desde la carpeta OPA
cd OPA

# Evaluación básica (muestra todas las violaciones)
.\evaluar_politica.ps1

# Evaluación con fallo si hay violaciones (útil para CI/CD)
.\evaluar_politica.ps1 -FailOnViolation

# Especificar archivos personalizados
.\evaluar_politica.ps1 -PlanFile "..\Terraform\tfplan.json" -PolicyFile "deny_public_internet.rego"
```

### Método 2: Usando OPA CLI Directamente

#### Evaluación básica - Ver todas las violaciones:
```powershell
opa eval --input "..\Terraform\tfplan.json" --data "deny_public_internet.rego" "data.terraform.deny_public_internet.deny"
```

#### Evaluación con formato legible:
```powershell
opa eval --input "..\Terraform\tfplan.json" --data "deny_public_internet.rego" --format pretty "data.terraform.deny_public_internet.deny"
```

#### Evaluación para CI/CD (falla si hay violaciones):
```powershell
opa eval --input "..\Terraform\tfplan.json" --data "deny_public_internet.rego" --fail-defined "data.terraform.deny_public_internet.violations"
```

---

## Qué Valida la Política

La política `deny_public_internet.rego` valida los siguientes recursos y configuraciones:

### ✅ Azure Storage Account (`azurerm_storage_account`)
- `allow_blob_public_access` debe ser `false` o no estar presente
- `public_network_access_enabled` (boolean) debe ser `false` o no estar presente
- `public_network_access` (string) debe ser `"Disabled"`, vacío, o no estar presente

### ✅ Azure Key Vault (`azurerm_key_vault`)
- `public_network_access_enabled` (boolean) debe ser `false` o no estar presente
- `public_network_access` (string) debe ser `"Disabled"`, vacío, o no estar presente
- **Nota**: Las validaciones de `network_acls` están actualmente deshabilitadas en el código

### ✅ Azure AI Services (`azurerm_ai_services`)
- `public_network_access_enabled` (boolean) debe ser `false` o no estar presente
- `public_network_access` (string) debe ser `"Disabled"`, vacío, o no estar presente

### ✅ Azure AI Foundry (`azurerm_ai_foundry`)
- `public_network_access_enabled` (boolean) debe ser `false` o no estar presente
- `public_network_access` (string) debe ser `"Disabled"`, vacío, o no estar presente

### ✅ Azure AI Foundry Project (`azurerm_ai_foundry_project`)
- `public_network_access_enabled` (boolean) debe ser `false` o no estar presente
- `public_network_access` (string) debe ser `"Disabled"`, vacío, o no estar presente

### ✅ Network Security Groups (`azurerm_network_security_group`)
- No debe haber reglas de salida (outbound) con `access = "Allow"` que permitan tráfico a:
  - `"*"` (cualquier destino)
  - `"Internet"` (tag de Azure)
  - `"0.0.0.0/0"` (toda la red)

### ✅ Recursos Genéricos (Catch-all)
- Cualquier recurso con `public_network_access_enabled = true` será rechazado
- Cualquier recurso con `public_network_access` (string) != `"Disabled"` será rechazado
- Excluye tipos específicos que ya tienen reglas dedicadas para evitar mensajes duplicados

---

## Ejemplo de Salida

### Cuando hay violaciones:

**Salida del Script PowerShell:**
```
========================================
Evaluación de Política OPA
Política: Deny Public Internet Access
========================================

✓ OPA encontrado: Version: 0.62.0
✓ Archivo de plan encontrado: ..\Terraform\tfplan.json
✓ Archivo de política encontrado: deny_public_internet.rego

Ejecutando evaluación...

✗ Violaciones encontradas:

  • Storage account azurerm_storage_account.rag has public_network_access_enabled = true (debe ser false)
  • Key Vault azurerm_key_vault.rag has public_network_access_enabled = true (debe ser false)
  • Network Security Group azurerm_network_security_group.example has an outbound rule 'AllowInternet' allowing traffic to 0.0.0.0/0
```

**Salida de OPA CLI:**
```json
[
  "Storage account azurerm_storage_account.rag has public_network_access_enabled = true (debe ser false)",
  "Key Vault azurerm_key_vault.rag has public_network_access_enabled = true (debe ser false)"
]
```

### Cuando no hay violaciones:

**Salida del Script PowerShell:**
```
========================================
Evaluación de Política OPA
Política: Deny Public Internet Access
========================================

✓ OPA encontrado: Version: 0.62.0
✓ Archivo de plan encontrado: ..\Terraform\tfplan.json
✓ Archivo de política encontrado: deny_public_internet.rego

Ejecutando evaluación...

✓ Política cumplida: No se encontraron violaciones
```

**Salida de OPA CLI:**
```
[]
```

---

## Integración con CI/CD

### Azure DevOps Pipeline

```yaml
- task: PowerShell@2
  displayName: 'Evaluar Política OPA'
  inputs:
    filePath: '$(System.DefaultWorkingDirectory)/OPA/evaluar_politica.ps1'
    arguments: '-FailOnViolation'
    failOnStderr: true
  continueOnError: false
```

### GitHub Actions

```yaml
- name: Instalar OPA
  run: |
    curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
    chmod +x opa
    sudo mv opa /usr/local/bin/

- name: Evaluar Política OPA
  run: |
    cd OPA
    pwsh -File evaluar_politica.ps1 -FailOnViolation
  continue-on-error: false
```

### Script Manual para Pipelines

```powershell
# En Azure DevOps, GitHub Actions, etc.
cd OPA
.\evaluar_politica.ps1 -FailOnViolation

if ($LASTEXITCODE -ne 0) {
    Write-Error "La política OPA encontró violaciones. Revisa la configuración de los recursos."
    exit 1
}
```

---

## Solución de Problemas

### Error: "OPA no está instalado o no está en el PATH"
**Causa**: OPA CLI no está instalado o no está en las variables de entorno PATH.

**Solución**:
1. Sigue las instrucciones en la sección [Instalación de OPA desde Cero](#instalación-de-opa-desde-cero)
2. Verifica que OPA está en el PATH:
   ```powershell
   # Windows PowerShell
   $env:Path -split ';' | Select-String -Pattern "OPA"
   
   # Linux/macOS
   which opa
   ```
3. Reinicia la terminal/PowerShell después de agregar al PATH
4. Verifica con: `opa version`

### Error: "No se encuentra el archivo de plan: tfplan.json"
**Causa**: El archivo de plan JSON no ha sido generado o la ruta es incorrecta.

**Solución**:
```powershell
cd ..\Terraform
terraform plan -out=tfplan.bin
terraform show -json tfplan.bin > tfplan.json
```

### Error: "No se encuentra el archivo de política: deny_public_internet.rego"
**Causa**: El script se está ejecutando desde un directorio incorrecto o el archivo no existe.

**Solución**:
- Asegúrate de ejecutar el script desde la carpeta `OPA`
- O especifica la ruta completa con `-PolicyFile`

### No se detectan violaciones cuando deberían
**Causa**: El plan JSON está desactualizado o los recursos no tienen las propiedades configuradas.

**Solución**:
1. Regenera el plan JSON:
   ```powershell
   cd ..\Terraform
   terraform plan -out=tfplan.bin -refresh
   terraform show -json tfplan.bin > tfplan.json
   ```
2. Verifica que los recursos en tu código Terraform tengan `public_network_access_enabled = true`
3. Revisa que el formato del plan JSON sea compatible (tfplan/v2)
4. Verifica que los nombres de los recursos en el plan coincidan con los esperados

### Violaciones duplicadas o mensajes confusos
**Causa**: Un recurso puede tener múltiples propiedades que violan la política.

**Solución**: Esto es esperado. Un recurso puede violar la política en múltiples formas (por ejemplo, tanto `public_network_access` como `public_network_access_enabled`). Revisa todos los mensajes y corrige todas las propiedades problemáticas.

### El script no falla en CI/CD aunque hay violaciones
**Causa**: No se está usando el parámetro `-FailOnViolation`.

**Solución**: Agrega el parámetro `-FailOnViolation` al ejecutar el script:
```powershell
.\evaluar_politica.ps1 -FailOnViolation
```

### Error de permisos en PowerShell (Windows)
**Causa**: La política de ejecución de PowerShell está configurada como "Restricted".

**Solución**:
```powershell
# Verificar política actual
Get-ExecutionPolicy

# Cambiar política (solo para el usuario actual)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# O ejecutar el script con bypass temporal
powershell -ExecutionPolicy Bypass -File .\evaluar_politica.ps1
```

---

## Prueba Rápida

Para probar que la política funciona correctamente:

1. **Temporalmente modifica un recurso** en `storage.tf` o `key_vault.tf`:
   ```hcl
   public_network_access_enabled = true  # Esto debería ser detectado como violación
   ```

2. **Regenera el plan JSON**:
   ```powershell
   cd ..\Terraform
   terraform plan -out=tfplan.bin
   terraform show -json tfplan.bin > tfplan.json
   ```

3. **Ejecuta la evaluación**:
   ```powershell
   cd ..\OPA
   .\evaluar_politica.ps1
   ```

4. **Deberías ver el mensaje de violación** en rojo.

5. **Revierte el cambio** y verifica que la política pasa.

---

## Referencias

- [Documentación de OPA](https://www.openpolicyagent.org/docs/latest/)
- [Lenguaje Rego](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [Terraform Plan Format](https://www.terraform.io/docs/internals/json-format.html)
- [Azure Resource Manager Terraform Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [OPA GitHub Releases](https://github.com/open-policy-agent/opa/releases)
- [OPA Playground](https://play.openpolicyagent.org/) - Para probar políticas Rego en línea
