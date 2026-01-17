# ==============================================================================
# SCRIPT: Evaluador de Política OPA para Terraform
# ==============================================================================
# Este script evalúa un plan de Terraform contra una política de OPA (Open Policy Agent)
# para verificar que no se creen recursos con acceso público a Internet.
#
# El script realiza las siguientes acciones:
# 1. Verifica que OPA esté instalado y disponible en el PATH
# 2. Valida que existan los archivos necesarios (plan de Terraform y política OPA)
# 3. Ejecuta la evaluación de la política usando OPA CLI
# 4. Parsea y muestra los resultados de forma legible
# 5. Maneja códigos de salida apropiados para integración en CI/CD
#
# Uso básico:
#   .\evaluar_politica.ps1
#
# Uso con parámetros personalizados:
#   .\evaluar_politica.ps1 -PlanFile "..\Terraform\mi_plan.json" -PolicyFile "mi_politica.rego"
#
# Uso con fallo automático en violaciones (útil para CI/CD):
#   .\evaluar_politica.ps1 -FailOnViolation
# ==============================================================================

# ------------------------------------------------------------------------------
# PARÁMETROS DEL SCRIPT
# ------------------------------------------------------------------------------
# Define los parámetros que el script acepta. Todos son opcionales y tienen
# valores por defecto que funcionan con la estructura estándar del proyecto.
# ------------------------------------------------------------------------------
param(
    # Ruta al archivo JSON del plan de Terraform (formato tfplan/v2)
    # Por defecto busca el plan en el directorio Terraform relativo a OPA
    [string]$PlanFile = "..\Terraform\tfplan.json",
    
    # Nombre del archivo de política OPA (formato .rego)
    # Por defecto usa la política deny_public_internet.rego en el directorio actual
    [string]$PolicyFile = "deny_public_internet.rego",
    
    # Si está habilitado, el script saldrá con código de error (1) si encuentra violaciones
    # Útil para pipelines de CI/CD que deben fallar automáticamente
    # Por defecto es $false, por lo que el script solo muestra advertencias
    [switch]$FailOnViolation = $false
)

# ------------------------------------------------------------------------------
# ENCABEZADO Y PRESENTACIÓN
# ------------------------------------------------------------------------------
# Muestra un encabezado visual para identificar claramente el inicio de la
# evaluación. Usa colores cyan para destacar la información.
# ------------------------------------------------------------------------------
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Evaluación de Política OPA" -ForegroundColor Cyan
Write-Host "Política: Deny Public Internet Access" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------
# VERIFICACIÓN 1: OPA CLI INSTALADO
# ------------------------------------------------------------------------------
# Verifica que el comando `opa` esté disponible en el PATH del sistema.
# Esto es crítico porque el script depende completamente de OPA para evaluar
# las políticas.
#
# Cómo funciona:
# - Intenta ejecutar `opa version` y captura tanto stdout como stderr (2>&1)
# - Si el comando tiene éxito, muestra la versión de OPA encontrada
# - Si falla (excepción o comando no encontrado), muestra un error y termina
#   el script con código de salida 1
# ------------------------------------------------------------------------------
try {
    # Ejecuta `opa version` y captura toda la salida (incluyendo errores)
    # 2>&1 redirige stderr a stdout para capturar también mensajes de error
    $opaVersion = opa version 2>&1
    
    # Extrae la primera línea de la salida (que contiene la versión)
    # y muestra un mensaje de éxito en verde
    Write-Host "✓ OPA encontrado: $($opaVersion -split "`n" | Select-Object -First 1)" -ForegroundColor Green
} catch {
    # Si ocurre una excepción (comando no encontrado, etc.), muestra error
    # y proporciona un enlace para descargar OPA
    Write-Host "✗ Error: OPA no está instalado o no está en el PATH" -ForegroundColor Red
    Write-Host "  Descarga OPA desde: https://www.openpolicyagent.org/docs/latest/#running-opa" -ForegroundColor Yellow
    # Sale con código de error 1 para indicar fallo
    exit 1
}

# ------------------------------------------------------------------------------
# VERIFICACIÓN 2: ARCHIVO DE PLAN DE TERRAFORM
# ------------------------------------------------------------------------------
# Verifica que el archivo JSON del plan de Terraform exista en la ruta especificada.
# El plan debe estar en formato JSON (tfplan/v2) que se genera con:
#   terraform plan -out=tfplan.bin
#   terraform show -json tfplan.bin > tfplan.json
#
# Este archivo contiene todos los cambios propuestos que Terraform aplicará,
# y es la entrada que OPA necesita para evaluar las políticas.
# ------------------------------------------------------------------------------
if (-not (Test-Path $PlanFile)) {
    # Si el archivo no existe, muestra un error y proporciona instrucciones
    # sobre cómo generar el plan
    Write-Host "✗ Error: No se encuentra el archivo de plan: $PlanFile" -ForegroundColor Red
    Write-Host "  Genera el plan primero con:" -ForegroundColor Yellow
    Write-Host "    cd ..\Terraform" -ForegroundColor Yellow
    Write-Host "    terraform plan -out=tfplan.bin" -ForegroundColor Yellow
    Write-Host "    terraform show -json tfplan.bin > tfplan.json" -ForegroundColor Yellow
    # Sale con código de error 1
    exit 1
}

# ------------------------------------------------------------------------------
# VERIFICACIÓN 3: ARCHIVO DE POLÍTICA OPA
# ------------------------------------------------------------------------------
# Verifica que el archivo de política OPA (formato .rego) exista.
# Este archivo contiene las reglas que se evaluarán contra el plan de Terraform.
# ------------------------------------------------------------------------------
if (-not (Test-Path $PolicyFile)) {
    # Si el archivo de política no existe, muestra error y termina
    Write-Host "✗ Error: No se encuentra el archivo de política: $PolicyFile" -ForegroundColor Red
    exit 1
}

# Si todas las verificaciones pasaron, muestra confirmación de archivos encontrados
Write-Host "✓ Archivo de plan encontrado: $PlanFile" -ForegroundColor Green
Write-Host "✓ Archivo de política encontrado: $PolicyFile" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# EJECUCIÓN DE LA EVALUACIÓN OPA
# ------------------------------------------------------------------------------
# Ejecuta OPA CLI para evaluar el plan de Terraform contra la política.
# La consulta busca el conjunto `deny` definido en la política, que contiene
# todos los mensajes de violación encontrados.
#
# Comando OPA ejecutado:
#   opa eval --input <PlanFile> --data <PolicyFile> --format pretty <query>
#
# Parámetros:
#   --input: Archivo JSON del plan de Terraform (entrada)
#   --data: Archivo de política OPA (.rego)
#   --format pretty: Formato de salida legible para humanos
#   <query>: Consulta Rego que retorna el conjunto de violaciones
# ------------------------------------------------------------------------------
Write-Host "Ejecutando evaluación..." -ForegroundColor Yellow
Write-Host ""

# Define la consulta Rego que se ejecutará
# Esta consulta accede al conjunto `deny` en el namespace de la política
# Formato: data.<package>.<rule>
# En este caso: data.terraform.deny_public_internet.deny
$query = "data.terraform.deny_public_internet.deny"

# Construye la lista de argumentos para el comando OPA
# Usa splatting (@argsList) para pasar los argumentos de forma segura
$argsList = @(
    'eval',                    # Comando: evaluar una consulta
    '--input', $PlanFile,      # Archivo de entrada (plan de Terraform)
    '--data', $PolicyFile,     # Archivo de política (.rego)
    '--format', 'pretty',      # Formato de salida legible
    $query                     # Consulta a ejecutar
)

try {
    # Ejecuta OPA con los argumentos especificados
    # & opa ejecuta el comando, @argsList pasa los argumentos usando splatting
    # 2>&1 redirige stderr a stdout para capturar todos los mensajes
    $output = & opa @argsList 2>&1
    
    # Captura el código de salida del comando OPA
    # En PowerShell, $LASTEXITCODE contiene el código de salida del último comando externo
    $exitCode = $LASTEXITCODE
    
    # --------------------------------------------------------------------------
    # PROCESAMIENTO DE RESULTADOS
    # --------------------------------------------------------------------------
    # Analiza la salida de OPA para determinar si hay violaciones.
    # OPA retorna diferentes formatos según el resultado:
    # - Si no hay violaciones: retorna "[]" (array vacío) o "undefined"
    # - Si hay violaciones: retorna un array JSON con los mensajes de violación
    # --------------------------------------------------------------------------
    
    # Verifica si la salida indica que NO hay violaciones
    # - '\[\]' busca un array vacío (los corchetes están escapados para regex)
    # - 'undefined' indica que la regla no se definió (no hay violaciones)
    if ($output -match '\[\]' -or $output -match 'undefined') {
        # Caso exitoso: no se encontraron violaciones
        Write-Host "✓ Política cumplida: No se encontraron violaciones" -ForegroundColor Green
        Write-Host ""
        # Sale con código 0 (éxito)
        exit 0
    } else {
        # Caso con violaciones: se encontraron problemas
        Write-Host "✗ Violaciones encontradas:" -ForegroundColor Red
        Write-Host ""
        
        # ----------------------------------------------------------------------
        # EXTRACCIÓN DE MENSAJES DE VIOLACIÓN
        # ----------------------------------------------------------------------
        # Intenta extraer los mensajes de violación de la salida de OPA.
        # Los mensajes están entre comillas dobles en el JSON de salida.
        # Usa regex para encontrar todos los strings entre comillas.
        # ----------------------------------------------------------------------
        $violations = $output | Select-String -Pattern '"(.*)"' | ForEach-Object {
            # Para cada coincidencia, extrae el contenido del grupo 1 (texto entre comillas)
            $_.Matches.Groups[1].Value
        }
        
        # Si se extrajeron violaciones exitosamente, las muestra formateadas
        if ($violations) {
            # Itera sobre cada violación y la muestra con un bullet point
            foreach ($violation in $violations) {
                Write-Host "  • $violation" -ForegroundColor Red
            }
        } else {
            # Si no se pudieron extraer violaciones (formato inesperado),
            # muestra la salida completa de OPA para depuración
            Write-Host $output
        }
        
        Write-Host ""
        
        # ----------------------------------------------------------------------
        # MANEJO DE CÓDIGO DE SALIDA SEGÚN CONFIGURACIÓN
        # ----------------------------------------------------------------------
        # Dependiendo del parámetro -FailOnViolation, el script puede:
        # - Fallar (exit 1): Útil para CI/CD que debe detenerse en violaciones
        # - Continuar (exit 0): Útil para ejecución manual donde solo se quiere
        #   ver las advertencias sin detener el flujo
        # ----------------------------------------------------------------------
        if ($FailOnViolation) {
            # Si -FailOnViolation está habilitado, termina con error
            Write-Host "La evaluación falló debido a violaciones de política." -ForegroundColor Red
            exit 1
        } else {
            # Si no está habilitado, solo muestra advertencia pero continúa
            Write-Host "Advertencia: Se encontraron violaciones, pero el script continúa." -ForegroundColor Yellow
            exit 0
        }
    }
} catch {
    # --------------------------------------------------------------------------
    # MANEJO DE ERRORES
    # --------------------------------------------------------------------------
    # Captura cualquier excepción que ocurra durante la ejecución de OPA.
    # Esto puede incluir:
    # - Errores de sintaxis en la política
    # - Problemas al leer los archivos
    # - Errores internos de OPA
    # - Problemas de formato en el plan de Terraform
    # --------------------------------------------------------------------------
    Write-Host "✗ Error al ejecutar OPA: $_" -ForegroundColor Red
    # Sale con código de error 1 para indicar fallo
    exit 1
}
