# Guía de Evaluación de Política OPA

Esta guía explica cómo usar la política OPA `deny_public_internet.rego` para validar que los recursos de Terraform no tengan acceso público habilitado.

## 📋 Tabla de Contenidos

1. [Prerrequisitos](#prerrequisitos)
2. [Documentación del Archivo Rego](#documentación-del-archivo-rego)
3. [Documentación del Script PowerShell](#documentación-del-script-powershell)
4. [Métodos de Evaluación](#métodos-de-evaluación)
5. [Qué Valida la Política](#qué-valida-la-política)
6. [Integración con CI/CD](#integración-con-cicd)
7. [Solución de Problemas](#solución-de-problemas)

---

## Prerrequisitos

1. **OPA CLI instalado**: Descarga desde https://www.openpolicyagent.org/docs/latest/#running-opa
   ```powershell
   # Verificar instalación
   opa version
   ```

2. **Plan de Terraform en formato JSON**: 
   ```powershell
   cd ..\Terraform
   terraform plan -out=tfplan.bin
   terraform show -json tfplan.bin > tfplan.json
   ```

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
cd DemoHashiTalkEspana2026\OPA

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
    filePath: '$(System.DefaultWorkingDirectory)/DemoHashiTalkEspana2026/OPA/evaluar_politica.ps1'
    arguments: '-FailOnViolation'
    failOnStderr: true
  continueOnError: false
```

### GitHub Actions

```yaml
- name: Evaluar Política OPA
  run: |
    cd DemoHashiTalkEspana2026/OPA
    pwsh -File evaluar_politica.ps1 -FailOnViolation
  continue-on-error: false
```

### Script Manual para Pipelines

```powershell
# En Azure DevOps, GitHub Actions, etc.
cd DemoHashiTalkEspana2026\OPA
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
1. Descarga OPA desde https://www.openpolicyagent.org/docs/latest/#running-opa
2. En Windows, agrega el directorio de OPA a la variable de entorno PATH
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
