# Script simplificado para evaluar la política OPA
# Uso: .\evaluar_politica.ps1

param(
    [string]$PlanFile = "..\Terraform\tfplan.json",
    [string]$PolicyFile = "deny_public_internet.rego",
    [switch]$FailOnViolation = $false
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Evaluación de Política OPA" -ForegroundColor Cyan
Write-Host "Política: Deny Public Internet Access" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que OPA esté instalado
try {
    $opaVersion = opa version 2>&1
    Write-Host "✓ OPA encontrado: $($opaVersion -split "`n" | Select-Object -First 1)" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: OPA no está instalado o no está en el PATH" -ForegroundColor Red
    Write-Host "  Descarga OPA desde: https://www.openpolicyagent.org/docs/latest/#running-opa" -ForegroundColor Yellow
    exit 1
}

# Verificar que el archivo de plan existe
if (-not (Test-Path $PlanFile)) {
    Write-Host "✗ Error: No se encuentra el archivo de plan: $PlanFile" -ForegroundColor Red
    Write-Host "  Genera el plan primero con:" -ForegroundColor Yellow
    Write-Host "    cd ..\Terraform" -ForegroundColor Yellow
    Write-Host "    terraform plan -out=tfplan.bin" -ForegroundColor Yellow
    Write-Host "    terraform show -json tfplan.bin > tfplan.json" -ForegroundColor Yellow
    exit 1
}

# Verificar que el archivo de política existe
if (-not (Test-Path $PolicyFile)) {
    Write-Host "✗ Error: No se encuentra el archivo de política: $PolicyFile" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Archivo de plan encontrado: $PlanFile" -ForegroundColor Green
Write-Host "✓ Archivo de política encontrado: $PolicyFile" -ForegroundColor Green
Write-Host ""

# Ejecutar evaluación
Write-Host "Ejecutando evaluación..." -ForegroundColor Yellow
Write-Host ""

$query = "data.terraform.deny_public_internet.deny"
$argsList = @('eval', '--input', $PlanFile, '--data', $PolicyFile, '--format', 'pretty', $query)

try {
    $output = & opa @argsList 2>&1
    $exitCode = $LASTEXITCODE
    
    # Mostrar resultados
    if ($output -match '\[\]' -or $output -match 'undefined') {
        Write-Host "✓ Política cumplida: No se encontraron violaciones" -ForegroundColor Green
        Write-Host ""
        exit 0
    } else {
        Write-Host "✗ Violaciones encontradas:" -ForegroundColor Red
        Write-Host ""
        
        # Extraer mensajes de violación del output
        $violations = $output | Select-String -Pattern '"(.*)"' | ForEach-Object {
            $_.Matches.Groups[1].Value
        }
        
        if ($violations) {
            foreach ($violation in $violations) {
                Write-Host "  • $violation" -ForegroundColor Red
            }
        } else {
            Write-Host $output
        }
        
        Write-Host ""
        
        if ($FailOnViolation) {
            Write-Host "La evaluación falló debido a violaciones de política." -ForegroundColor Red
            exit 1
        } else {
            Write-Host "Advertencia: Se encontraron violaciones, pero el script continúa." -ForegroundColor Yellow
            exit 0
        }
    }
} catch {
    Write-Host "✗ Error al ejecutar OPA: $_" -ForegroundColor Red
    exit 1
}
