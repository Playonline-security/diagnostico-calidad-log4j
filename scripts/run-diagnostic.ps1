<#
.SYNOPSIS
  Coordinador del diagnostico de calidad (componente didactico V-A / V-B + analisis SCA Log4j).

.DESCRIPTION
  Ejecuta por fases las herramientas ya configuradas en el proyecto (Maven Surefire /
  Jazzer / SpotBugs + FindSecBugs / verificacion local de Dependency-Check) y conserva
  logs, reportes y metadatos trazables en evidencias/ejecuciones/<timestamp>/.

  El script coordina herramientas reales; no simula su salida. Los mensajes propios
  llevan el prefijo [DIAG] para distinguirlos de la salida nativa.

.PARAMETER Fase
  Fase a ejecutar: junit | fuzz-va | fuzz-vb | spotbugs | dependency-check | all.
  Cada modo individual ejecuta solo la fase solicitada mas las comprobaciones
  estrictamente necesarias. El modo all las ejecuta en orden
  junit -> fuzz-va -> fuzz-vb -> spotbugs -> dependency-check.

.PARAMETER MaxDuration
  Duracion para fuzzing con generacion de Jazzer (p. ej. "90s"). Solo tiene efecto
  en fuzz-vb (y fuzz-va) cuando se combina con -Generar. Por defecto "90s".

.PARAMETER Generar
  Solo para fuzz-vb / fuzz-va: activa JAZZER_FUZZ=1 con generacion de entradas
  durante MaxDuration. Sin este conmutador ambas fases ejecutan regresion
  determinista (solo semillas existentes). La regresion NO debe presentarse
  como sesion de fuzzing prolongada.

.PARAMETER NoUpdate
  Reservado para la fase dependency-check. Dicha fase funciona en modo de
  verificacion local (sin red, sin NVD, sin regenerar reportes). Si se invoca
  con -NoUpdate:$false el script rechaza la sincronizacion externa y explica
  como ejecutarla manualmente.

.EXAMPLE
  .\scripts\run-diagnostic.ps1 -Fase junit
.EXAMPLE
  .\scripts\run-diagnostic.ps1 -Fase fuzz-va
.EXAMPLE
  .\scripts\run-diagnostic.ps1 -Fase fuzz-vb -Generar -MaxDuration "90s"
.EXAMPLE
  .\scripts\run-diagnostic.ps1 -Fase spotbugs
.EXAMPLE
  .\scripts\run-diagnostic.ps1 -Fase dependency-check
.EXAMPLE
  .\scripts\run-diagnostic.ps1 -Fase all

.NOTES
  Requisitos: JDK 21 (recomendado), Apache Maven 3.9.x, PowerShell 7 preferido.
  No instala ni actualiza herramientas. No registra secretos.
  Alcance didactico: V-A/V-B son un resolvedor de plantillas local sin JNDI/LDAP/RMI
  ni red; no reproducen la explotacion de Log4Shell. Los analisis SCA sobre
  log4j-core 2.14.1/2.17.1 son complementarios y se distinguen siempre.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, HelpMessage = "Fase: junit|fuzz-va|fuzz-vb|spotbugs|dependency-check|all")]
  [ValidateSet("junit", "fuzz-va", "fuzz-vb", "spotbugs", "dependency-check", "all")]
  [string]$Fase,

  [Parameter(Mandatory = $false)]
  [string]$MaxDuration = "90s",

  [Parameter(Mandatory = $false)]
  [switch]$Generar,

  [Parameter(Mandatory = $false)]
  [bool]$NoUpdate = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------- raiz robusta
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ExpDir   = Join-Path $RepoRoot "experimento-didactico"
$PomExp   = Join-Path $ExpDir "pom.xml"
$PomAfec  = Join-Path $RepoRoot "analisis-log4j/afectada/pom.xml"
$PomCorr  = Join-Path $RepoRoot "analisis-log4j/corregida/pom.xml"
$ArgLineJazzer = "-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading"

function Write-Diag {
  param([string]$Msg, [string]$Color = "Cyan")
  Write-Host "[DIAG] $Msg" -ForegroundColor $Color
}

function Write-PhaseHeader {
  param([string]$Titulo)
  $line = "=" * 72
  Write-Host ""
  Write-Host $line -ForegroundColor DarkCyan
  Write-Host "  $Titulo" -ForegroundColor Yellow
  Write-Host $line -ForegroundColor DarkCyan
}

function Get-ToolVersions {
  $info = [ordered]@{}
  try { $info["powershell"] = $PSVersionTable.PSVersion.ToString() } catch { $info["powershell"] = "desconocida" }
  try {
    $mvnOut = & mvn -version 2>&1 | Out-String
    $info["maven"] = ($mvnOut -split "`r?`n" | Select-Object -First 1).Trim()
  } catch { $info["maven"] = "no disponible: $_" }
  try {
    $javaOut = & java -version 2>&1 | Out-String
    $info["java"] = ($javaOut -split "`r?`n" | Select-Object -First 1).Trim()
  } catch { $info["java"] = "no disponible: $_" }
  return $info
}

function Assert-Prereqs {
  param([string[]]$NeedMvn = @(), [string]$FaseNombre)
  $mvn = Get-Command mvn -ErrorAction SilentlyContinue
  if (-not $mvn) {
    Write-Diag "Falta 'mvn' en PATH. Instala Apache Maven 3.9.x. Fase $FaseNombre no ejecutable." -Color Red
    throw "Infraestructura: mvn no disponible"
  }
  $java = Get-Command java -ErrorAction SilentlyContinue
  if (-not $java) {
    Write-Diag "Falta 'java' en PATH. Se recomienda JDK 21. Fase $FaseNombre no ejecutable." -Color Red
    throw "Infraestructura: java no disponible"
  }
  foreach ($f in $NeedMvn) {
    if (-not (Test-Path -LiteralPath $f)) {
      Write-Diag "No existe el archivo requerido: $f. Fase $FaseNombre no ejecutable." -Color Red
      throw "Infraestructura: falta $f"
    }
  }
}

function New-ExecutionDir {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $base = Join-Path $RepoRoot ("evidencias/ejecuciones/" + $stamp)
  $n = 0
  while (Test-Path -LiteralPath $base) {
    $n++
    $base = Join-Path $RepoRoot ("evidencias/ejecuciones/" + $stamp + "-" + $n.ToString("00"))
  }
  New-Item -ItemType Directory -Path $base | Out-Null
  return $base
}

<#
 .SYNOPSIS Invoca un proceso nativo conservando stdout/stderr por separado y el exit code.
 .NOTES Decision documentada: se usa Start-Process con -RedirectStandardOutput/Error
  y -Wait -PassThru para no perder el codigo de salida (Tee-Object / pipes lo
  oscurecen). La salida se muestra en consola DESPUES de la ejecucion leyendo los
  ficheros capturados, con etiquetas [STDOUT]/[STDERR]; el contenido es el real
  de la herramienta, sin alteraciones.
#>
function Invoke-Captured {
  param(
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$WorkDir,
    [string]$StdoutFile,
    [string]$StderrFile,
    [hashtable]$ExtraEnv
  )
  $oldEnv = @{}
  if ($ExtraEnv) {
    foreach ($k in $ExtraEnv.Keys) {
      $oldEnv[$k] = [Environment]::GetEnvironmentVariable($k, "Process")
      [Environment]::SetEnvironmentVariable($k, $ExtraEnv[$k], "Process")
    }
  }
  $cmdLine = "$FilePath $($Arguments -join ' ')"
  Write-Diag "Comando : $cmdLine" -Color White
  Write-Diag "CWD     : $WorkDir" -Color White
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments `
      -WorkingDirectory $WorkDir `
      -RedirectStandardOutput $StdoutFile -RedirectStandardError $StderrFile `
      -NoNewWindow -Wait -PassThru
    $exit = $p.ExitCode
  } finally {
    $sw.Stop()
    if ($ExtraEnv) {
      foreach ($k in $ExtraEnv.Keys) {
        [Environment]::SetEnvironmentVariable($k, $oldEnv[$k], "Process")
      }
    }
  }
  # Reproducir salida real en consola (etiquetada, sin modificar contenido)
  if (Test-Path -LiteralPath $StdoutFile) {
    Write-Host "----- [STDOUT] $FilePath -----" -ForegroundColor DarkGray
    Get-Content -LiteralPath $StdoutFile | ForEach-Object { Write-Host $_ }
  }
  if ((Test-Path -LiteralPath $StderrFile) -and ((Get-Item -LiteralPath $StderrFile).Length -gt 0)) {
    Write-Host "----- [STDERR] $FilePath -----" -ForegroundColor DarkRed
    Get-Content -LiteralPath $StderrFile | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  }
  Write-Diag ("Exit code original: $exit | Duracion: " + [math]::Round($sw.Elapsed.TotalSeconds, 1) + " s") -Color White
  return [pscustomobject]@{ ExitCode = $exit; DurationS = [math]::Round($sw.Elapsed.TotalSeconds, 2); Command = $cmdLine }
}

function Get-FreshReports {
  # target/surefire-reports acumula restos de corridas anteriores: solo se aceptan
  # ficheros con LastWriteTime posterior al inicio de esta ejecucion (tolerancia 2 s).
  param([string]$ReportsDir, [string[]]$Include, [datetime]$Since)
  $all = Get-ChildItem -Path (Join-Path $ReportsDir "*") -Include $Include -ErrorAction SilentlyContinue
  $fresh = @($all | Where-Object { $_.LastWriteTime -ge $Since.AddSeconds(-2) })
  $stale = @($all | Where-Object { $_.LastWriteTime -lt $Since.AddSeconds(-2) })
  return [pscustomobject]@{ Fresh = $fresh; Stale = $stale }
}

function Read-SurefireSummary {
  param([string]$ReportsDir, [string[]]$Include = @("*.txt"))
  $rows = @()
  # Solo se consideran los ficheros indicados: target/surefire-reports acumula
  # restos de ejecuciones anteriores y no debe mezclarse con la fase actual.
  $files = Get-ChildItem -Path (Join-Path $ReportsDir "*") -Include $Include -ErrorAction SilentlyContinue
  foreach ($txt in $files) {
    $m = Select-String -LiteralPath $txt.FullName -Pattern "Tests run:\s*(\d+),\s*Failures:\s*(\d+),\s*Errors:\s*(\d+),\s*Skipped:\s*(\d+)" | Select-Object -First 1
    if ($m) { $rows += ("{0}: {1}" -f $txt.Name, $m.Line.Trim()) }
    else { $rows += ("{0}: sin linea de resumen parseable" -f $txt.Name) }
  }
  if ($rows.Count -eq 0) { $rows += "(sin reportes coincidentes en $ReportsDir para: $($Include -join ', '))" }
  return $rows
}

function Copy-Reports {
  param([string]$FromDir, [string]$ToDir, [string[]]$Patterns)
  New-Item -ItemType Directory -Path $ToDir -Force | Out-Null
  $copied = @()
  foreach ($pat in $Patterns) {
    foreach ($f in Get-ChildItem -Path (Join-Path $FromDir $pat) -ErrorAction SilentlyContinue) {
      Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $ToDir $f.Name) -Force
      $copied += $f.Name
    }
  }
  return $copied
}

function Write-Manifest {
  param([string]$ExecDir, [hashtable]$Data)
  $path = Join-Path $ExecDir "manifest.json"
  $json = ($Data | ConvertTo-Json -Depth 6)
  Set-Content -LiteralPath $path -Value $json -Encoding UTF8
  # Validar que el JSON puede analizarse
  Get-Content -LiteralPath $path -Raw | ConvertFrom-Json | Out-Null
  if (-not (Test-Json -Path $path)) { throw "manifest.json no valido en $path" }
  Write-Diag "Manifiesto validado: $path" -Color Green
}

# ============================================================ fases concretas

function Invoke-FaseJUnit {
  param([string]$ExecDir, [hashtable]$Versions)
  Write-PhaseHeader "FASE junit — pruebas unitarias y de regresion (V-A + V-B)"
  Assert-Prereqs -NeedMvn @($PomExp) -FaseNombre "junit"
  $phaseDir = Join-Path $ExecDir "junit"; New-Item -ItemType Directory -Path $phaseDir | Out-Null
  $stdout = Join-Path $phaseDir "stdout.log"; $stderr = Join-Path $phaseDir "stderr.log"
  $t0 = (Get-Date).ToString("o")
  $mvn = (Get-Command mvn).Source
  $args = @("--batch-mode",
    "-Dtest=ResolutorPlantillasTest,ResolutorPlantillasCorregidoTest",
    "-Dsurefire.failIfNoSpecifiedTests=false", "test")
  $r = Invoke-Captured -FilePath $mvn -Arguments $args -WorkDir $ExpDir -StdoutFile $stdout -StderrFile $stderr
  $t1 = (Get-Date).ToString("o")
  $reports = Join-Path $ExpDir "target/surefire-reports"
  $unitInclude = @("edu.proyecto.calidad.plantillas.ResolutorPlantillasTest.txt",
                   "edu.proyecto.calidad.plantillas.ResolutorPlantillasCorregidoTest.txt")
  $summary = Read-SurefireSummary -ReportsDir $reports -Include $unitInclude
  Write-Diag "Resumen Surefire (leido de target/surefire-reports/*.txt):" -Color Yellow
  $summary | ForEach-Object { Write-Host "  $_" }
  Write-Diag "Esperado: ResolutorPlantillasTest 12 tests 0 fallos; ResolutorPlantillasCorregidoTest 19 tests 0 fallos. Contrastar con XML." -Color Yellow
  $repDir = Join-Path $phaseDir "reportes"; New-Item -ItemType Directory -Path $repDir -Force | Out-Null
  $copied = Copy-Reports -FromDir $reports -ToDir $repDir -Patterns @("edu.proyecto.calidad.plantillas.ResolutorPlantillasTest.txt", "edu.proyecto.calidad.plantillas.ResolutorPlantillasCorregidoTest.txt", "TEST-edu.proyecto.calidad.plantillas.ResolutorPlantillasTest.xml", "TEST-edu.proyecto.calidad.plantillas.ResolutorPlantillasCorregidoTest.xml")
  Write-Diag ("Reportes copiados a junit/reportes/: " + ($copied -join ", ")) -Color Green
  return [ordered]@{
    fase = "junit"; inicio = $t0; fin = $t1; comando = $r.Command
    directorio_trabajo = $ExpDir; exit_code = $r.ExitCode; duracion_s = $r.DurationS
    stdout = "junit/stdout.log"; stderr = "junit/stderr.log"; reportes = @("junit/reportes/")
    resumen_surefire = $summary; ficheros_copiados = @($copied); notas = "No mezcla fuzzing. Cifras solo de reportes leidos."
  }
}

function Invoke-FaseFuzzVA {
  param([string]$ExecDir, [hashtable]$Versions, [bool]$Generar, [string]$MaxDuration)
  Write-PhaseHeader "FASE fuzz-va — fuzzing de V-A (HALL-001 esperado)"
  Assert-Prereqs -NeedMvn @($PomExp) -FaseNombre "fuzz-va"
  Write-Diag "Semillas configuradas en codigo: ana | 'ana `${minusculas:XYZ}' (referencia HALL-001) | 'ana `${girar:xy}' | 'a `${b' | 'a } b'. Sin semilla vacia (ENV-003)." -Color Yellow
  $phaseDir = Join-Path $ExecDir "fuzz-va"; New-Item -ItemType Directory -Path $phaseDir | Out-Null
  $stdout = Join-Path $phaseDir "stdout.log"; $stderr = Join-Path $phaseDir "stderr.log"
  $t0dt = Get-Date; $t0 = $t0dt.ToString("o")
  $mvn = (Get-Command mvn).Source
  # NOTA: Start-Process no entrecomilla automaticamente los argumentos con espacios;
  # el valor de -DargLine debe llevar comillas dobles explicitas o Maven lo partiria
  # (el fragmento "-XX:..." se interpretaria como -X/debug + objetivo "X:...").
  $args = @("--batch-mode", "-Dtest=ResolutorPlantillasFuzzTest",
    '"-DargLine=-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading"',
    "-Dsurefire.failIfNoSpecifiedTests=false", "test")
  $extra = $null
  if ($Generar) {
    Write-Diag "Generacion activada: JAZZER_FUZZ=1 JAZZER_MAX_DURATION=$MaxDuration" -Color Yellow
    $extra = @{ JAZZER_FUZZ = "1"; JAZZER_MAX_DURATION = $MaxDuration }
  } else {
    Write-Diag "Regresion determinista (solo semillas, sin JAZZER_FUZZ). El fallo de la semilla de referencia es el hallazgo HALL-001, no un error de infraestructura." -Color Yellow
  }
  $r = Invoke-Captured -FilePath $mvn -Arguments $args -WorkDir $ExpDir -StdoutFile $stdout -StderrFile $stderr -ExtraEnv $extra
  $t1 = (Get-Date).ToString("o")
  if ($r.ExitCode -ne 0) {
    Write-Diag "Exit != 0 en fuzz-va: resultado tecnico ESPERADO si corresponde a HALL-001 (expected:<Hola, ANA `${minusculas:XYZ}> but was:<Hola, ANA xyz>). No implica fallo metodologico. Verificar en surefire TXT/XML." -Color Yellow
  }
  $reports = Join-Path $ExpDir "target/surefire-reports"
  $fresh = Get-FreshReports -ReportsDir $reports -Include @("edu.proyecto.calidad.plantillas.ResolutorPlantillasFuzzTest.txt", "TEST-edu.proyecto.calidad.plantillas.ResolutorPlantillasFuzzTest.xml") -Since $t0dt
  if ($fresh.Stale.Count -gt 0 -and $fresh.Fresh.Count -eq 0) {
    Write-Diag "AVISO INFRA: Surefire no regenero reportes en esta ejecucion (exit=$($r.ExitCode)); los ficheros presentes son restos anteriores y NO se usan como evidencia." -Color Red
  }
  $summary = Read-SurefireSummary -ReportsDir $reports -Include @("edu.proyecto.calidad.plantillas.ResolutorPlantillasFuzzTest.txt")
  # Reescribir el resumen solo con ficheros frescos cuando existan
  $freshTxt = @($fresh.Fresh | Where-Object { $_.Extension -eq ".txt" })
  if ($freshTxt.Count -gt 0) {
    $summary = @()
    foreach ($txt in $freshTxt) {
      $m = Select-String -LiteralPath $txt.FullName -Pattern "Tests run:\s*(\d+),\s*Failures:\s*(\d+),\s*Errors:\s*(\d+),\s*Skipped:\s*(\d+)" | Select-Object -First 1
      if ($m) { $summary += ("{0}: {1}" -f $txt.Name, $m.Line.Trim()) }
    }
  } elseif ($r.ExitCode -ne 0) {
    $summary = @("(sin reporte Surefire fresco: la ejecucion no llego a las pruebas; ver stdout/stderr.log)")
  }
  $summary | ForEach-Object { Write-Host "  $_" }
  $art = Join-Path $phaseDir "artefactos"; New-Item -ItemType Directory -Path $art -Force | Out-Null
  $copied = @()
  foreach ($f in $fresh.Fresh) {
    Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $art $f.Name) -Force
    $copied += $f.Name
  }
  foreach ($c in Get-ChildItem -LiteralPath $ExpDir -Filter "crash-*" -ErrorAction SilentlyContinue) {
    Copy-Item -LiteralPath $c.FullName -Destination (Join-Path $art $c.Name) -Force
    $copied += $c.Name
  }
  $corpusCount = 0
  $corpusDir = Join-Path $ExpDir ".cifuzz-corpus"
  if (Test-Path -LiteralPath $corpusDir) {
    $corpusCount = (Get-ChildItem -LiteralPath $corpusDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
  }
  Write-Diag "Corpus actual (conteo, no copiado): $corpusCount ficheros en .cifuzz-corpus/ (excluido de Git)." -Color White
  return [ordered]@{
    fase = "fuzz-va"; inicio = $t0; fin = $t1; comando = $r.Command
    directorio_trabajo = $ExpDir; exit_code = $r.ExitCode; duracion_s = $r.DurationS
    stdout = "fuzz-va/stdout.log"; stderr = "fuzz-va/stderr.log"; artefactos = @("fuzz-va/artefactos/")
    resumen_surefire = $summary; corpus_ficheros = $corpusCount; generacion = $Generar
    ficheros_copiados = @($copied)
    reporte_fresco = ($fresh.Fresh.Count -gt 0)
    notas = "HALL-001 es resultado relevante solo si el reporte Surefire es fresco y muestra la asercion esperada. Exit!=0 sin reporte fresco = fallo de infraestructura, no hallazgo. Semilla no alterada."
  }
}

function Invoke-FaseFuzzVB {
  param([string]$ExecDir, [hashtable]$Versions, [bool]$Generar, [string]$MaxDuration)
  Write-PhaseHeader "FASE fuzz-vb — fuzzing de V-B (sin errores registrados != ausencia de defectos)"
  Assert-Prereqs -NeedMvn @($PomExp) -FaseNombre "fuzz-vb"
  $phaseDir = Join-Path $ExecDir "fuzz-vb"; New-Item -ItemType Directory -Path $phaseDir | Out-Null
  $stdout = Join-Path $phaseDir "stdout.log"; $stderr = Join-Path $phaseDir "stderr.log"
  $t0dt = Get-Date; $t0 = $t0dt.ToString("o")
  $mvn = (Get-Command mvn).Source
  $args = @("--batch-mode", "-Dtest=ResolutorPlantillasCorregidoFuzzTest",
    '"-DargLine=-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading"',
    "-Dsurefire.failIfNoSpecifiedTests=false", "test")
  $extra = $null
  if ($Generar) {
    Write-Diag "Generacion activada: JAZZER_FUZZ=1 JAZZER_MAX_DURATION=$MaxDuration. Se registra duracion/corpus reales." -Color Yellow
    $extra = @{ JAZZER_FUZZ = "1"; JAZZER_MAX_DURATION = $MaxDuration }
  } else {
    Write-Diag "Regresion determinista (6 semillas incl. larga de 10001 caracteres con rechazo IllegalArgumentException). NO presentarla como sesion prolongada." -Color Yellow
  }
  $r = Invoke-Captured -FilePath $mvn -Arguments $args -WorkDir $ExpDir -StdoutFile $stdout -StderrFile $stderr -ExtraEnv $extra
  $t1 = (Get-Date).ToString("o")
  $reports = Join-Path $ExpDir "target/surefire-reports"
  $freshVB = Get-FreshReports -ReportsDir $reports -Include @("edu.proyecto.calidad.plantillas.ResolutorPlantillasCorregidoFuzzTest.txt", "TEST-edu.proyecto.calidad.plantillas.ResolutorPlantillasCorregidoFuzzTest.xml") -Since $t0dt
  if ($freshVB.Stale.Count -gt 0 -and $freshVB.Fresh.Count -eq 0) {
    Write-Diag "AVISO INFRA: Surefire no regenero reportes en esta ejecucion; no usar restos anteriores como evidencia." -Color Red
  }
  $summary = Read-SurefireSummary -ReportsDir $reports -Include @("edu.proyecto.calidad.plantillas.ResolutorPlantillasCorregidoFuzzTest.txt")
  $freshTxtVB = @($freshVB.Fresh | Where-Object { $_.Extension -eq ".txt" })
  if ($freshTxtVB.Count -gt 0) {
    $summary = @()
    foreach ($txt in $freshTxtVB) {
      $m = Select-String -LiteralPath $txt.FullName -Pattern "Tests run:\s*(\d+),\s*Failures:\s*(\d+),\s*Errors:\s*(\d+),\s*Skipped:\s*(\d+)" | Select-Object -First 1
      if ($m) { $summary += ("{0}: {1}" -f $txt.Name, $m.Line.Trim()) }
    }
  }
  $summary | ForEach-Object { Write-Host "  $_" }
  Write-Diag "Cero errores aqui describe solo el alcance de esta ejecucion (semillas + duracion). No demuestra correccion universal." -Color Yellow
  $art = Join-Path $phaseDir "artefactos"; New-Item -ItemType Directory -Path $art -Force | Out-Null
  $copied = @()
  foreach ($f in $freshVB.Fresh) {
    Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $art $f.Name) -Force
    $copied += $f.Name
  }
  $corpusCount = 0
  $corpusDir = Join-Path $ExpDir ".cifuzz-corpus"
  if (Test-Path -LiteralPath $corpusDir) {
    $corpusCount = (Get-ChildItem -LiteralPath $corpusDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
  }
  Write-Diag "Corpus actual (conteo, no copiado): $corpusCount ficheros." -Color White
  return [ordered]@{
    fase = "fuzz-vb"; inicio = $t0; fin = $t1; comando = $r.Command
    directorio_trabajo = $ExpDir; exit_code = $r.ExitCode; duracion_s = $r.DurationS
    stdout = "fuzz-vb/stdout.log"; stderr = "fuzz-vb/stderr.log"; artefactos = @("fuzz-vb/artefactos/")
    resumen_surefire = $summary; corpus_ficheros = $corpusCount; generacion = $Generar
    ficheros_copiados = @($copied)
    reporte_fresco = ($freshVB.Fresh.Count -gt 0)
    notas = "Alcance limitado a semillas/duracion registradas. Sin afirmaciones de seguridad."
  }
}

function Invoke-FaseSpotbugs {
  param([string]$ExecDir, [hashtable]$Versions)
  Write-PhaseHeader "FASE spotbugs — analisis estatico (SpotBugs + FindSecBugs)"
  Assert-Prereqs -NeedMvn @($PomExp) -FaseNombre "spotbugs"
  Write-Diag "Herramienta: spotbugs-maven-plugin 4.8.3.1 + findsecbugs-plugin 1.14.0 (segun pom). Alcance: ambas variantes (V-A y V-B) conjuntamente." -Color Yellow
  $phaseDir = Join-Path $ExecDir "spotbugs"; New-Item -ItemType Directory -Path $phaseDir | Out-Null
  $stdout = Join-Path $phaseDir "stdout.log"; $stderr = Join-Path $phaseDir "stderr.log"
  $t0 = (Get-Date).ToString("o")
  $mvn = (Get-Command mvn).Source
  $args = @("--batch-mode", "compile", "spotbugs:check")
  $r = Invoke-Captured -FilePath $mvn -Arguments $args -WorkDir $ExpDir -StdoutFile $stdout -StderrFile $stderr
  $t1 = (Get-Date).ToString("o")
  $xml = Join-Path $ExpDir "target/spotbugsXml.xml"
  $bugInfo = "no evaluado"
  if (Test-Path -LiteralPath $xml) {
    $m1 = Select-String -LiteralPath $xml -Pattern "total_bugs='(\d+)'" | Select-Object -First 1
    $m2 = Select-String -LiteralPath $xml -Pattern "total_classes='(\d+)'" | Select-Object -First 1
    $bugInfo = "spotbugsXml.xml: " + $m1.Line.Substring(0, [math]::Min(200, $m1.Line.Length))
    Write-Diag $bugInfo -Color White
    if ($m2) { Write-Diag ("Clases analizadas (FindBugsSummary): " + $m2.Matches[0].Value) -Color White }
  } else {
    Write-Diag "No se encontro target/spotbugsXml.xml tras la ejecucion." -Color Red
  }
  $repDir = Join-Path $phaseDir "reportes"; New-Item -ItemType Directory -Path $repDir -Force | Out-Null
  $copied = Copy-Reports -FromDir (Join-Path $ExpDir "target") -ToDir $repDir -Patterns @("spotbugsXml.xml")
  Write-Diag "Cero hallazgos NO demuestra ausencia de vulnerabilidades (V-A contiene la reinterpretacion documentada)." -Color Yellow
  return [ordered]@{
    fase = "spotbugs"; inicio = $t0; fin = $t1; comando = $r.Command
    directorio_trabajo = $ExpDir; exit_code = $r.ExitCode; duracion_s = $r.DurationS
    stdout = "spotbugs/stdout.log"; stderr = "spotbugs/stderr.log"; reportes = @("spotbugs/reportes/")
    detalle = $bugInfo; ficheros_copiados = @($copied); notas = "Analisis conjunto V-A+V-B. Cero != seguro."
  }
}

function Invoke-FaseDependencyCheck {
  param([string]$ExecDir, [hashtable]$Versions, [bool]$NoUpdate)
  Write-PhaseHeader "FASE dependency-check — VERIFICACION LOCAL (sin red, sin NVD, sin regenerar)"
  Write-Diag "Proyectos: analisis-log4j/afectada (log4j-core 2.14.1) y corregida (2.17.1). NO ejecutar update/check contra red en esta fase." -Color Yellow
  if (-not $NoUpdate) {
    Write-Diag "Se solicito -NoUpdate:`$false, pero la sincronizacion externa esta deshabilitada por politica (coste de horas, credenciales NVD). Ejecuta manualmente: mvn --batch-mode -f analisis-log4j/afectada/pom.xml org.owasp:dependency-check-maven:13.0.0:check" -Color Red
    Write-Diag "Se continua en modo verificacion local de los reportes historicos del 2026-10-09." -Color Yellow
  }
  $phaseDir = Join-Path $ExecDir "dependency-check"; New-Item -ItemType Directory -Path $phaseDir | Out-Null
  $stdout = Join-Path $phaseDir "stdout.log"; $stderr = Join-Path $phaseDir "stderr.log"
  "" | Set-Content -LiteralPath $stdout -Encoding UTF8
  "" | Set-Content -LiteralPath $stderr -Encoding UTF8
  $t0 = (Get-Date).ToString("o"); $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $files = @(
    "analisis-log4j/afectada/target/dependency-check-report.html",
    "analisis-log4j/afectada/target/dependency-check-report.json",
    "analisis-log4j/corregida/target/dependency-check-report.html",
    "analisis-log4j/corregida/target/dependency-check-report.json"
  )
  $rows = @(); $missing = @(); $exit = 0
  foreach ($rel in $files) {
    $abs = Join-Path $RepoRoot $rel
    if (Test-Path -LiteralPath $abs) {
      $len = (Get-Item -LiteralPath $abs).Length
      $line = "[DIAG] OK $rel ($len bytes)"; Write-Host $line -ForegroundColor Green
      Add-Content -LiteralPath $stdout -Value $line
      $rows += ("OK {0} ({1} bytes)" -f $rel, $len)
    } else {
      $line = "[DIAG] FALTA $rel — se registra ausencia, no se reconstruye"; Write-Host $line -ForegroundColor Red
      Add-Content -LiteralPath $stderr -Value $line
      $missing += $rel; $exit = 2
    }
  }
  $verif = @()
  foreach ($rel in @("analisis-log4j/afectada/target/dependency-check-report.json",
                     "analisis-log4j/corregida/target/dependency-check-report.json")) {
    $abs = Join-Path $RepoRoot $rel
    if (Test-Path -LiteralPath $abs) {
      try {
        if (-not (Test-Json -Path $abs)) { throw "Test-Json fallo" }
        $d = Get-Content -LiteralPath $abs -Raw | ConvertFrom-Json
        $nDeps = @($d.dependencies).Count
        $allV = @(); $perDep = @()
        foreach ($dep in @($d.dependencies)) {
          $nv = @($dep.vulnerabilities).Count
          $perDep += ("{0}: {1}" -f $dep.fileName, $nv)
          foreach ($v in @($dep.vulnerabilities)) { $allV += $v.name }
        }
        $uniq = @($allV | Sort-Object -Unique)
        $l = ("{0}: deps={1}; por-dep=[{2}]; CVEunicos={3} [{4}]" -f $rel, $nDeps, ($perDep -join "; "), $uniq.Count, ($uniq -join ", "))
        Write-Host "[DIAG] $l" -ForegroundColor White
        Add-Content -LiteralPath $stdout -Value ("[DIAG] " + $l)
        $verif += $l
      } catch {
        $l = ("{0}: JSON NO VALIDO ({1})" -f $rel, $_.Exception.Message)
        Write-Host "[DIAG] $l" -ForegroundColor Red
        Add-Content -LiteralPath $stderr -Value ("[DIAG] " + $l)
        $exit = 3
      }
    }
  }
  # Contraste HTML (conteos originales, sin reinterpretar)
  foreach ($rel in @("analisis-log4j/afectada/target/dependency-check-report.html",
                     "analisis-log4j/corregida/target/dependency-check-report.html")) {
    $abs = Join-Path $RepoRoot $rel
    if (Test-Path -LiteralPath $abs) {
      $m = Select-String -LiteralPath $abs -Pattern "Vulnerabilities Found</i>:&nbsp;(\d+)" | Select-Object -First 1
      $l = ("{0}: HTML {1}" -f $rel, ($m ? $m.Matches[0].Value : "conteo no localizado"))
      Write-Host "[DIAG] $l" -ForegroundColor White
      Add-Content -LiteralPath $stdout -Value ("[DIAG] " + $l)
      $verif += $l
    }
  }
  $adv = @(
    "Asociacion CVE != explotabilidad en una aplicacion concreta (POMs minimos sin appenders/config).",
    "2.17.1 fue comparador historico frente a Log4Shell; con NVD a 2026-10-09 mantiene 5 CVE posteriores: NO presentarla como segura.",
    "Informes de 2026-10-09; no se les atribuye fecha nueva. Ver resultados-auditoria/auditoria_cve_dependency_check.md."
  )
  $adv | ForEach-Object { Write-Host "[DIAG] ADVERTENCIA: $_" -ForegroundColor Yellow; Add-Content -LiteralPath $stdout -Value ("[DIAG] ADVERTENCIA: " + $_) }
  $sw.Stop(); $t1 = (Get-Date).ToString("o")
  Write-Diag ("Verificacion DC terminada. Exit: $exit | Duracion: " + [math]::Round($sw.Elapsed.TotalSeconds, 1) + " s") -Color White
  return [ordered]@{
    fase = "dependency-check"; inicio = $t0; fin = $t1; comando = "verificacion local (sin mvn, sin red)"
    directorio_trabajo = $RepoRoot; exit_code = $exit; duracion_s = [math]::Round($sw.Elapsed.TotalSeconds, 2)
    stdout = "dependency-check/stdout.log"; stderr = "dependency-check/stderr.log"
    archivos = $rows; faltantes = $missing; verificacion_json_html = $verif; advertencias = $adv
    notas = "Modo verificacion. failBuildOnCVSS=11 implica BUILD SUCCESS aunque haya CVEs."
  }
}

# ============================================================ orquestacion
$versions = Get-ToolVersions
Write-PhaseHeader "DIAGNOSTICO DE CALIDAD — coordinador (fase: $Fase)"
Write-Diag ("RepoRoot: " + $RepoRoot) -Color White
Write-Diag ("PowerShell: " + $versions["powershell"]) -Color White
Write-Diag ("Maven     : " + $versions["maven"]) -Color White
Write-Diag ("Java      : " + $versions["java"]) -Color White
Write-Diag ("Jazzer argLine: $ArgLineJazzer (inyectado solo en fases fuzz)") -Color White
Write-Diag "Separacion obligatoria: V-A/V-B (didactico, sin JNDI/LDAP/RMI/red) != analisis SCA de log4j-core real." -Color Yellow

$execDir = New-ExecutionDir
Write-Diag ("Ejecucion: " + (Split-Path -Leaf $execDir) + " -> $execDir") -Color Green

$fasesPedidas = @()
if ($Fase -eq "all") { $fasesPedidas = @("junit", "fuzz-va", "fuzz-vb", "spotbugs", "dependency-check") }
else { $fasesPedidas = @($Fase) }

$resultados = @()
$infraFallo = $false
foreach ($f in $fasesPedidas) {
  try {
    switch ($f) {
      "junit"             { $resultados += Invoke-FaseJUnit -ExecDir $execDir -Versions $versions }
      "fuzz-va"           { $resultados += Invoke-FaseFuzzVA -ExecDir $execDir -Versions $versions -Generar ([bool]$Generar) -MaxDuration $MaxDuration }
      "fuzz-vb"           { $resultados += Invoke-FaseFuzzVB -ExecDir $execDir -Versions $versions -Generar ([bool]$Generar) -MaxDuration $MaxDuration }
      "spotbugs"          { $resultados += Invoke-FaseSpotbugs -ExecDir $execDir -Versions $versions }
      "dependency-check"  { $resultados += Invoke-FaseDependencyCheck -ExecDir $execDir -Versions $versions -NoUpdate $NoUpdate }
    }
    $last = $resultados[-1]
    # 'all' continua tras exit tecnico esperado de fuzz-va SOLO si hay reporte fresco
    # que lo respalde; sin reporte fresco es fallo de infraestructura y se detiene.
    if ($Fase -eq "all" -and $f -eq "fuzz-va") {
      if (([int]$last["exit_code"]) -ne 0 -and $last.Contains("reporte_fresco") -and (-not $last["reporte_fresco"])) {
        Write-Diag "fuzz-va devolvio exit distinto de cero SIN reporte Surefire fresco: fallo de infraestructura, no HALL-001. Se detiene 'all'." -Color Red
        $infraFallo = $true
        break
      }
    }
    # 'all' continua tras exit tecnico esperado de fuzz-va; se detiene ante infra real
    if ($Fase -eq "all" -and $f -ne "fuzz-va" -and ([int]$last["exit_code"]) -ne 0 -and $f -ne "dependency-check") {
      if ($f -eq "junit" -or $f -eq "spotbugs" -or $f -eq "fuzz-vb") {
        Write-Diag ("La fase $f devolvio exit " + $last["exit_code"] + ". En modo all se detiene por posible problema de infraestructura/fiabilidad.") -Color Red
        $infraFallo = $true
        break
      }
    }
  } catch {
    Write-Diag ("ERROR de infraestructura en fase ${f}: " + $_.Exception.Message) -Color Red
    $resultados += [ordered]@{ fase = $f; error_infraestructura = $_.Exception.Message; exit_code = 99 }
    $infraFallo = $true
    if ($Fase -eq "all") { break }
    else { throw }
  }
}

# Resumen y manifiesto con datos reales
$resumenPath = Join-Path $execDir "resumen.md"
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Resumen de ejecucion " + (Split-Path -Leaf $execDir))
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- Fase(s): " + ($fasesPedidas -join ", "))
[void]$sb.AppendLine("- Generar (fuzz con entradas nuevas): " + ([bool]$Generar))
[void]$sb.AppendLine("- Versiones: PS=" + $versions["powershell"] + " | " + $versions["maven"] + " | " + $versions["java"])
foreach ($r in $resultados) {
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("## " + $r["fase"] + " (exit " + $r["exit_code"] + ")")
  if ($r.Contains("comando")) { [void]$sb.AppendLine("- Comando: ``" + $r["comando"] + "``") }
  if ($r.Contains("inicio")) { [void]$sb.AppendLine("- Inicio/fin: " + $r["inicio"] + " / " + $r["fin"] + " (" + $r["duracion_s"] + " s)") }
  if ($r.Contains("resumen_surefire")) { foreach ($s in $r["resumen_surefire"]) { [void]$sb.AppendLine("- " + $s) } }
  if ($r.Contains("detalle")) { [void]$sb.AppendLine("- " + $r["detalle"]) }
  if ($r.Contains("archivos")) { foreach ($s in $r["archivos"]) { [void]$sb.AppendLine("- " + $s) } }
  if ($r.Contains("ficheros_copiados")) { [void]$sb.AppendLine("- Ficheros copiados: " + ($r["ficheros_copiados"] -join ", ")) }
  if ($r.Contains("reporte_fresco")) { [void]$sb.AppendLine("- Reporte Surefire fresco de esta ejecucion: " + $r["reporte_fresco"]) }
  if ($r.Contains("verificacion_json_html")) { foreach ($s in $r["verificacion_json_html"]) { [void]$sb.AppendLine("- " + $s) } }
  if ($r.Contains("advertencias")) { foreach ($s in $r["advertencias"]) { [void]$sb.AppendLine("- Advertencia: " + $s) } }
  if ($r.Contains("notas")) { [void]$sb.AppendLine("- Nota: " + $r["notas"]) }
  if ($r.Contains("error_infraestructura")) { [void]$sb.AppendLine("- ERROR INFRA: " + $r["error_infraestructura"]) }
}
if ($infraFallo -and $Fase -eq "all") { [void]$sb.AppendLine(""); [void]$sb.AppendLine("> Ejecucion detenida por posible error de infraestructura. Revisar stderr.log de la fase.") }
Set-Content -LiteralPath $resumenPath -Value $sb.ToString() -Encoding UTF8

$manifest = [ordered]@{
  id = (Split-Path -Leaf $execDir); fases = $fasesPedidas
  parametros = [ordered]@{ Fase = $Fase; MaxDuration = $MaxDuration; Generar = [bool]$Generar; NoUpdate = [bool]$NoUpdate }
  versiones = $versions; repo_root = $RepoRoot
  resultados = $resultados
  advertencias = @(
    "Componente didactico sin JNDI/LDAP/RMI/red; no es Log4j real.",
    "HALL-001 (V-A) es resultado tecnico esperado con exit!=0; no es fallo metodologico.",
    "Cero errores en V-B / cero hallazgos SpotBugs no prueban ausencia de defectos.",
    "DC en modo verificacion local de reportes 2026-10-09; asociacion CVE != explotabilidad; 2.17.1 no es version segura actual."
  )
}
Write-Manifest -ExecDir $execDir -Data $manifest

Write-PhaseHeader "FIN — evidencias en $execDir"
Write-Diag "Manifiesto: $execDir/manifest.json | Resumen: $execDir/resumen.md" -Color Green
foreach ($r in $resultados) { Write-Diag ("- " + $r["fase"] + ": exit " + $r["exit_code"]) -Color White }

if ($infraFallo) { exit 1 }
$worst = 0
foreach ($r in $resultados) {
  if ($r["fase"] -eq "fuzz-va") { continue }  # exit!=0 esperado por HALL-001 no contamina el codigo global
  if ([int]$r["exit_code"] -gt $worst) { $worst = [int]$r["exit_code"] }
}
exit $worst
