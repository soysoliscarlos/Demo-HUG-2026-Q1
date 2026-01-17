# Guía Completa de OPA para Validación de Políticas Terraform

Esta guía explica cómo instalar, configurar y usar Open Policy Agent (OPA) con la política `deny_public_internet.rego` para validar que los recursos de Terraform no tengan acceso público habilitado.

## 🎓 ¿Qué es Open Policy Agent (OPA)?

**Open Policy Agent (OPA)** es un motor de políticas de código abierto que unifica la aplicación de políticas en toda la pila tecnológica. Permite definir políticas como código y evaluarlas contra datos estructurados (como planes de Terraform, configuraciones de Kubernetes, etc.).

### Conceptos Clave de OPA

#### 1. **Políticas como Código**
- Define reglas de negocio y seguridad en archivos `.rego`
- Versiona políticas con Git
- Evalúa políticas antes de aplicar cambios (shift-left security)

#### 2. **Lenguaje Rego**
- Lenguaje declarativo diseñado para políticas
- Sintaxis clara y expresiva
- Basado en lógica de primer orden

#### 3. **Evaluación de Políticas**
- OPA evalúa políticas contra datos de entrada (input)
- En este proyecto: evalúa planes de Terraform (JSON)
- Retorna violaciones si encuentra problemas

#### 4. **Reglas Deny/Allow**
- **Deny**: Reglas que prohíben ciertas configuraciones
- **Allow**: Reglas que permiten configuraciones específicas
- En este proyecto: usamos reglas `deny` para bloquear acceso público

#### 5. **Input Data**
- Datos que OPA evalúa contra las políticas
- En este proyecto: plan de Terraform en formato JSON (`tfplan.json`)
- OPA lee el plan y verifica cada recurso

### ¿Por qué usar OPA?

✅ **Prevención**: Detecta problemas antes de aplicar cambios  
✅ **Consistencia**: Aplica las mismas políticas en todos los entornos  
✅ **Automatización**: Integra con CI/CD para validación automática  
✅ **Multi-plataforma**: Mismo lenguaje para Terraform, Kubernetes, APIs, etc.  
✅ **Declarativo**: Define "qué" quieres, no "cómo" lograrlo  
✅ **Auditoría**: Documenta qué políticas se aplican y cuándo

### Flujo de Trabajo con OPA

```
1. Terraform plan → 2. Convertir a JSON → 3. OPA evalúa → 4. Aplicar o corregir
     ↓                    ↓                    ↓                    ↓
  Plan binario        tfplan.json         Violaciones          Cambios seguros
```

### En este Proyecto

OPA valida que ningún recurso de Azure tenga acceso público habilitado:

**Política**: `deny_public_internet.rego`  
**Valida**:
- Storage Accounts sin acceso público (blob access y network access)
- Key Vaults sin acceso público
- Network Security Groups sin reglas de salida abiertas a Internet
- Cualquier recurso genérico con flags de acceso público (catch-all)

**Estructura**:
- **8 reglas deny**: Cada una valida un tipo específico de recurso o configuración
- **1 regla violations**: Para uso en CI/CD con `--fail-defined`
- **5 funciones helper**: Simplifican la lógica y permiten reutilización de código

**Resultado**: Si hay violaciones, OPA las lista antes de aplicar cambios con Terraform. El script `evaluar_politica.ps1` automatiza la evaluación con validaciones y formato de salida coloreado.

## 📋 Tabla de Contenidos

1. [¿Qué es Open Policy Agent (OPA)?](#-qué-es-open-policy-agent-opa)
2. [Instalación de OPA desde Cero](#instalación-de-opa-desde-cero)
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

**Recursos validados:**
- Azure Storage Account (blob público y acceso de red público)
- Azure Key Vault (acceso de red público)
- Network Security Groups (reglas de salida que permiten tráfico a Internet)
- Recursos genéricos con flags de acceso público (catch-all)

#### Estructura del Archivo

**Encabezado y Documentación (líneas 1-21)**
- Comentarios descriptivos que explican el propósito de la política
- Lista de recursos validados: Storage Account, Key Vault, Network Security Groups, y recursos genéricos
- Resumen de reglas y funciones helper incluidas

**Paquete y Configuración (líneas 23-30)**
```rego
package terraform.deny_public_internet
import rego.v1
```
- Define el paquete de la política con el namespace `terraform.deny_public_internet`
- Importa la sintaxis moderna de Rego (`rego.v1`) para usar sintaxis más clara y moderna
- El namespace se usa para acceder a las reglas desde OPA CLI: `data.terraform.deny_public_internet.deny`

**Reglas de Denegación por Tipo de Recurso**

La política contiene **8 reglas `deny`** que se evalúan independientemente. Cada regla verifica un tipo específico de recurso o condición:

1. **REGLA 1: Azure Storage Account - Blob Public Access (líneas 48-83)**
   - Verifica que `allow_blob_public_access` no sea `true`
   - Esta es una configuración de seguridad crítica que puede exponer datos sensibles públicamente
   - Mensaje: `"Storage account {name} has allow_blob_public_access = true"`

2. **REGLA 2: Azure Storage Account - Public Network Access (String) (líneas 85-121)**
   - Verifica que `public_network_access` (string) sea `"Disabled"` o vacío
   - Convierte a minúsculas para comparación case-insensitive
   - Maneja variaciones como "Enabled", "ENABLED", "enabled", etc.
   - Mensaje: `"Storage account {name} has public_network_access = {value}"`

3. **REGLA 3: Azure Storage Account - Public Network Access (Boolean) (líneas 123-150)**
   - Verifica que `public_network_access_enabled` (boolean) sea `false`
   - Usa función helper `is_boolean()` para validar el tipo y evitar falsos positivos
   - Mensaje: `"Storage account {name} has public_network_access_enabled = true (debe ser false)"`

4. **REGLA 4: Azure Key Vault - Public Network Access (String) (líneas 152-180)**
   - Verifica que `public_network_access` (string) sea `"Disabled"` o vacío
   - Los Key Vaults contienen secretos y credenciales, por lo que el acceso público es un riesgo crítico
   - Comparación case-insensitive
   - Mensaje: `"Key Vault {name} has public network access enabled"`

5. **REGLA 5: Azure Key Vault - Public Network Access (Boolean) (líneas 182-205)**
   - Verifica que `public_network_access_enabled` (boolean) sea `false`
   - Usa función helper `is_boolean()` para validar el tipo
   - Mensaje: `"Key Vault {name} has public_network_access_enabled = true (debe ser false)"`

6. **REGLA 6: Catch-all para Recursos Genéricos - Public Network Access (String) (líneas 207-250)**
   - Verifica cualquier recurso con `public_network_access` (string) que no sea `"Disabled"` o null
   - Excluye tipos específicos que ya tienen reglas dedicadas para evitar mensajes duplicados
   - Excluye: `azurerm_storage_account`, `azurerm_key_vault`
   - Mensaje: `"Resource {name} ({type}) has public_network_access = {value}"`

7. **REGLA 7: Catch-all para Recursos Genéricos - Public Network Access (Boolean) (líneas 252-282)**
   - Verifica cualquier recurso con `public_network_access_enabled = true`
   - Usa función helper `is_boolean()` para validar el tipo antes de comparar
   - Excluye tipos específicos que ya tienen reglas dedicadas
   - Excluye: `azurerm_storage_account`, `azurerm_key_vault`
   - Mensaje: `"Resource {name} ({type}) has public_network_access_enabled = true (debe ser false)"`

8. **REGLA 8: Network Security Group - Reglas de Salida a Internet (líneas 284-336)**
   - Verifica reglas de salida (outbound) con `direction = "Outbound"` y `access = "Allow"`
   - Usa funciones helper `arrayify()`, `get_destination()` e `is_open_internet()` para identificar destinos públicos
   - Detecta destinos: `"*"` (wildcard), `"Internet"` (tag de Azure), `"0.0.0.0/0"` (toda la red IPv4)
   - Comparación case-insensitive
   - Mensaje: `"Network Security Group {name} has an outbound rule '{rule_name}' allowing traffic to {destination}"`

#### Funciones Helper (líneas 338-510)

La política incluye **5 funciones helper** que simplifican la lógica de las reglas y permiten reutilizar código común:

**`is_array(val)` (líneas 349-366)**
- Verifica si un valor es un array usando pattern matching de Rego
- Intenta acceder a un índice arbitrario; si el acceso es válido, el valor es un array
- Uso: Utilizada por la función `arrayify()` para verificar el tipo de dato
- Ejemplo: `is_array([1, 2, 3])` retorna `true`, `is_array("string")` retorna `false`

**`arrayify(val)` (líneas 368-395)**
- Convierte un valor a lista. Si ya es una lista, la retorna tal cual
- Si no es una lista (null, objeto, string, etc.), retorna una lista vacía
- Útil para normalizar valores que pueden ser arrays o null, permitiendo iterar sobre ellos de forma segura
- Uso: Utilizada en REGLA 8 para normalizar `security_rule` en Network Security Groups
- Ejemplo: `arrayify([1, 2])` retorna `[1, 2]`, `arrayify(null)` retorna `[]`

**`get_destination(rule)` (líneas 397-444)**
- Determina el prefijo de dirección de destino para una regla de NSG
- Las reglas de NSG pueden tener el destino en dos formatos:
  1. `destination_address_prefixes` (array de prefijos) - tiene prioridad
  2. `destination_address_prefix` (string con un solo prefijo) - fallback
- Prioriza el array si existe y tiene elementos, y hace fallback al string si el array está vacío o es null
- **IMPORTANTE**: Si una regla tiene múltiples prefijos en el array, esta función solo retorna el primer elemento
- Uso: Utilizada en REGLA 8 para obtener el destino de las reglas de NSG
- Ejemplo: Si `rule` tiene `destination_address_prefixes = ["0.0.0.0/0", "10.0.0.0/8"]`, retorna `"0.0.0.0/0"` (primer elemento)

**`is_open_internet(prefix)` (líneas 446-481)**
- Verifica si un prefijo de dirección representa acceso abierto a Internet
- Considera válidos los siguientes valores (case-insensitive):
  - `"*"` (cualquier destino - wildcard)
  - `"internet"` (tag de Azure que representa Internet)
  - `"0.0.0.0/0"` (notación CIDR que representa toda la red IPv4)
- Usa `lower()` para normalizar la comparación y hacerla case-insensitive
- Uso: Utilizada en REGLA 8 para identificar si una regla de NSG permite tráfico a Internet abierto
- Ejemplo: `is_open_internet("Internet")` retorna `true`, `is_open_internet("10.0.0.0/8")` no se define (retorna `false` implícitamente)

**`is_boolean(x)` (líneas 483-510)**
- Verifica si un valor es de tipo booleano
- Retorna `true` si el valor es `true` o `false`
- No se define (retorna `false` implícitamente) si el valor es null, string, number, etc.
- Esta función es útil para validar tipos antes de hacer comparaciones, evitando falsos positivos cuando un campo puede tener diferentes tipos
- Uso: Utilizada en REGLA 3 (Storage Account) y REGLA 5 (Key Vault) para validar que `public_network_access_enabled` es realmente un boolean antes de compararlo con `true`
- Ejemplo: `is_boolean(true)` retorna `true`, `is_boolean("true")` no se define (retorna `false` implícitamente)

#### Regla de Violaciones (líneas 512-536)

```rego
violations if {
    count(deny) > 0
}
```

- Esta regla booleana se define **SOLO** cuando hay violaciones (cuando el conjunto `deny` tiene elementos)
- Útil para usar con `--fail-defined` en OPA CLI, lo que hace que el comando salga con código de error no-cero si existen violaciones
- **NOTA**: Esta regla no se evalúa directamente por `evaluar_politica.ps1`, pero está disponible para uso en pipelines de CI/CD que requieren fallar automáticamente cuando hay violaciones
- **Comportamiento**:
  - Si hay violaciones: `violations` se define (retorna `true`) y el comando falla
  - Si no hay violaciones: `violations` no se define (retorna `false` implícitamente) y el comando tiene éxito
- **Uso en CI/CD**:
  ```powershell
  opa eval --input ../Terraform/tfplan.json \
           --data deny_public_internet.rego \
           --fail-defined "data.terraform.deny_public_internet.violations"
  ```

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

El script realiza las siguientes acciones en orden:

**1. Encabezado y Presentación (líneas 44-50)**
- Muestra un encabezado visual formateado con colores cyan
- Indica el nombre de la política que se está evaluando: "Deny Public Internet Access"

**2. Verificación de OPA CLI Instalado (líneas 52-75)**
```powershell
$opaVersion = opa version 2>&1
```
- Intenta ejecutar `opa version` para verificar que OPA está instalado y disponible en el PATH
- Captura tanto stdout como stderr (`2>&1`) para capturar todos los mensajes
- Si el comando tiene éxito, muestra la versión de OPA encontrada en verde
- Si falla (excepción o comando no encontrado), muestra error con enlace de descarga y sale con código 1

**3. Verificación de Archivo de Plan de Terraform (líneas 77-95)**
- Verifica que el archivo JSON del plan de Terraform exista en la ruta especificada
- El plan debe estar en formato JSON (tfplan/v2) generado con:
  ```powershell
  terraform plan -out=tfplan.bin
  terraform show -json tfplan.bin > tfplan.json
  ```
- Si no existe, muestra instrucciones para generarlo y sale con código 1

**4. Verificación de Archivo de Política OPA (líneas 97-105)**
- Verifica que el archivo de política OPA (formato .rego) exista
- Si no existe, muestra error y termina con código 1
- Si todas las verificaciones pasaron, muestra confirmación de archivos encontrados en verde

**5. Ejecución de la Evaluación OPA (líneas 107-145)**
```powershell
$query = "data.terraform.deny_public_internet.deny"
$argsList = @('eval', '--input', $PlanFile, '--data', $PolicyFile, '--format', 'pretty', $query)
$output = & opa @argsList 2>&1
```
- Define la consulta Rego que accede al conjunto `deny` en el namespace de la política
- Construye la lista de argumentos para OPA CLI usando splatting (`@argsList`)
- Ejecuta OPA con formato legible (`--format pretty`) capturando toda la salida
- Captura el código de salida del comando OPA usando `$LASTEXITCODE`

**6. Procesamiento de Resultados (líneas 147-213)**

**Si no hay violaciones:**
- Detecta patrones `[]` (array vacío) o `undefined` en la salida usando regex
- Muestra mensaje de éxito en verde: "✓ Política cumplida: No se encontraron violaciones"
- Sale con código 0 (éxito)

**Si hay violaciones:**
- Muestra encabezado de violaciones en rojo: "✗ Violaciones encontradas:"
- Extrae mensajes de violación usando expresiones regulares:
  ```powershell
  $violations = $output | Select-String -Pattern '"(.*)"' | ForEach-Object {
      $_.Matches.Groups[1].Value
  }
  ```
- Muestra cada violación como una lista con viñetas (•) en rojo
- Si no se pudieron extraer violaciones (formato inesperado), muestra la salida completa de OPA para depuración
- **Manejo de código de salida según configuración:**
  - Si `$FailOnViolation` está habilitado: termina con error (exit 1) - útil para CI/CD
  - Si no está habilitado: muestra advertencia en amarillo y continúa (exit 0) - útil para ejecución manual

**7. Manejo de Errores (líneas 214-224)**
- Captura cualquier excepción que ocurra durante la ejecución de OPA
- Esto puede incluir:
  - Errores de sintaxis en la política
  - Problemas al leer los archivos
  - Errores internos de OPA
  - Problemas de formato en el plan de Terraform
- Muestra mensaje de error en rojo y sale con código 1

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
- **REGLA 1**: `allow_blob_public_access` debe ser `false` o no estar presente
- **REGLA 2**: `public_network_access` (string) debe ser `"Disabled"`, vacío, o no estar presente (comparación case-insensitive)
- **REGLA 3**: `public_network_access_enabled` (boolean) debe ser `false` o no estar presente

### ✅ Azure Key Vault (`azurerm_key_vault`)
- **REGLA 4**: `public_network_access` (string) debe ser `"Disabled"`, vacío, o no estar presente (comparación case-insensitive)
- **REGLA 5**: `public_network_access_enabled` (boolean) debe ser `false` o no estar presente

### ✅ Network Security Groups (`azurerm_network_security_group`)
- **REGLA 8**: No debe haber reglas de salida (outbound) con `direction = "Outbound"` y `access = "Allow"` que permitan tráfico a:
  - `"*"` (cualquier destino - wildcard)
  - `"Internet"` (tag de Azure que representa Internet)
  - `"0.0.0.0/0"` (notación CIDR que representa toda la red IPv4)
- La validación es case-insensitive y maneja tanto `destination_address_prefix` (string) como `destination_address_prefixes` (array)

### ✅ Recursos Genéricos (Catch-all)
- **REGLA 6**: Cualquier recurso con `public_network_access` (string) != `"Disabled"` y != null será rechazado
  - Verifica explícitamente que el campo no sea null antes de evaluar
  - Comparación case-insensitive
  - Excluye tipos específicos que ya tienen reglas dedicadas: `azurerm_storage_account`, `azurerm_key_vault`
- **REGLA 7**: Cualquier recurso con `public_network_access_enabled = true` será rechazado
  - Usa función helper `is_boolean()` para validar el tipo antes de comparar
  - Excluye tipos específicos que ya tienen reglas dedicadas: `azurerm_storage_account`, `azurerm_key_vault`

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

### Conceptos Clave que Debes Entender

#### 1. **Lenguaje Rego**
- Lenguaje declarativo diseñado para políticas
- Basado en lógica de primer orden
- Sintaxis clara y expresiva
- Ejemplo:
  ```rego
  deny contains msg if {
      input.resource_changes[i].type == "azurerm_storage_account"
      input.resource_changes[i].change.after.public_network_access_enabled == true
      msg := "Storage account has public access enabled"
  }
  ```

#### 2. **Reglas y Conjuntos**
- **Reglas**: Definen condiciones y resultados
- **Conjuntos**: Colecciones de valores (como `deny`)
- **Múltiples reglas**: Todas se evalúan y agregan al conjunto

#### 3. **Input Data**
- Datos que OPA evalúa contra las políticas
- En este proyecto: plan de Terraform en JSON
- Acceso: `input.resource_changes[i].change.after`

#### 4. **Queries**
- Consultas que extraen información de las políticas
- Ejemplo: `data.terraform.deny_public_internet.deny`
- Retorna el conjunto de violaciones encontradas

#### 5. **Funciones Helper**
- Funciones auxiliares para reutilizar lógica
- Simplifican reglas complejas
- Ejemplo: `is_boolean()`, `arrayify()`, `is_open_internet()`

#### 6. **Evaluación**
- OPA evalúa todas las reglas contra el input
- Si una regla se cumple, agrega al conjunto de resultados
- Retorna todas las violaciones encontradas

### Próximos Pasos en tu Aprendizaje

1. **Básico**: Entiende la sintaxis Rego y cómo escribir reglas simples
2. **Intermedio**: Aprende a usar funciones helper y manejar arrays/objetos
3. **Avanzado**: Crea políticas complejas con múltiples condiciones
4. **Expert**: Integra OPA en pipelines CI/CD y múltiples plataformas

### Documentación Oficial

- [Documentación de OPA](https://www.openpolicyagent.org/docs/latest/)
- [Lenguaje Rego](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [OPA Policy Examples](https://www.openpolicyagent.org/docs/latest/policy-examples/)
- [Terraform Plan Format](https://www.terraform.io/docs/internals/json-format.html)

### Tutoriales y Recursos

- [OPA Playground](https://play.openpolicyagent.org/) - Para probar políticas Rego en línea
- [OPA Tutorials](https://www.openpolicyagent.org/docs/latest/tutorials/)
- [Rego by Example](https://github.com/StyraInc/rego-by-example)
- [Azure Resource Manager Terraform Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### Comunidad y Soporte

- [OPA GitHub](https://github.com/open-policy-agent/opa)
- [OPA Slack](https://slack.openpolicyagent.org/)
- [OPA Discourse](https://discuss.openpolicyagent.org/)
- [Stack Overflow - OPA Tag](https://stackoverflow.com/questions/tagged/open-policy-agent)
