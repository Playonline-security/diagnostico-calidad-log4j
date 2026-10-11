# Diagnóstico de calidad del software — componente didáctico inspirado en Log4Shell

Entorno reproducible que compara dos variantes de un resolvedor de plantillas de
registro: **V-A** (`ResolutorPlantillas`, con reinterpretación deliberada del dato)
y **V-B** (`ResolutorPlantillasCorregido`, una sola pasada + límites de longitud).
Técnicas: JUnit 5, fuzzing con Jazzer + oráculo independiente, SpotBugs +
FindSecBugs y análisis SCA de `log4j-core` real con OWASP Dependency-Check.

> **Alcance didáctico.** V-A/V-B son un resolvedor local de cadenas (funciones
> inocuas `minusculas`, `mayusculas`, `longitud`), **sin red, sin JNDI/LDAP/RMI,
> sin carga dinámica ni ejecución de código**. No es el código de Apache Log4j ni
> reproduce la explotación de Log4Shell (CVE-2021-44228). Los análisis de
> dependencias sobre Log4j 2.14.1/2.17.1 son complementarios y se distinguen siempre.

## Requisitos

- JDK 21 recomendado (bytecode `release 11`), Apache Maven 3.9.x, PowerShell 7.
- Sin claves ni servicios externos para el componente didáctico.
- Dependency-Check se usa aquí en modo verificación local (sin sincronizar NVD).

## Inicio rápido

```powershell
# Desde la raíz del repositorio
pwsh -NoProfile -File ./scripts/run-diagnostic.ps1 -Fase junit              # E-01
pwsh -NoProfile -File ./scripts/run-diagnostic.ps1 -Fase fuzz-va            # E-02 (HALL-001, exit 1 esperado)
pwsh -NoProfile -File ./scripts/run-diagnostic.ps1 -Fase fuzz-vb            # E-03 (regresión; exit 0)
pwsh -NoProfile -File ./scripts/run-diagnostic.ps1 -Fase fuzz-vb -Generar -MaxDuration "90s"  # E-03 con generación
pwsh -NoProfile -File ./scripts/run-diagnostic.ps1 -Fase spotbugs           # E-04
pwsh -NoProfile -File ./scripts/run-diagnostic.ps1 -Fase dependency-check   # E-05 (verificación local)
pwsh -NoProfile -File ./scripts/run-diagnostic.ps1 -Fase all                # todas (continúa tras HALL-001)
```

Cada ejecución crea `evidencias/ejecuciones/<AAAAMMDD-HHMMSS>/` con `manifest.json`,
`resumen.md` y `stdout.log`/`stderr.log` por fase. Los mensajes propios llevan el
prefijo `[DIAG]`; el resto es salida real de las herramientas.

## Resultados y evidencias

- [`evidencias/resultados/README.md`](evidencias/resultados/README.md) — vista pública
  por técnica (pruebas, fuzzing V-A/V-B, estático, dependencias) con artefactos
  sanitizados y [`TRAZABILIDAD.md`](evidencias/resultados/TRAZABILIDAD.md).
- [`resultados-auditoria/auditoria_cve_dependency_check.md`](resultados-auditoria/auditoria_cve_dependency_check.md)
  — auditoría de los 9 CVE de Dependency-Check.

Últimas ejecuciones verificadas (2026-10-11): junit 31/31 en verde; fuzz V-A 6
tests con 1 error (HALL-001: `expected:<Hola, ANA ${minusculas:XYZ}> but was:<Hola, ANA xyz>`,
exit 1); fuzz V-B 7/7 sin errores; SpotBugs 0 hallazgos; DC 12 vs 8 asociaciones
(9 vs 5 CVE únicos).

## V-A frente a V-B (ejemplo canónico)

Plantilla autorizada `Hola, ${mayusculas:nombre}` con dato no confiable
`ana ${minusculas:XYZ}` (`DemoHall001Runner` lo muestra por consola):

| Aspecto | V-A | V-B |
|---|---|---|
| Expansión | Reexpande hasta punto fijo (máx. 100 pasadas) | Una sola pasada; valores como texto literal |
| Resultado | `Hola, ANA xyz` (dato reinterpretado) | `Hola, ANA ${minusculas:XYZ}` (inerte, auditable) |
| Límites | Sin límites | Plantilla ≤ 100 000, valores ≤ 10 000, rechazo con `IllegalArgumentException` |

## Advertencias de interpretación

- HALL-001 con exit ≠ 0 es el resultado relevante de V-A, no un fallo metodológico.
- Cero errores en V-B, cero hallazgos SpotBugs o un DC `BUILD SUCCESS`
  (`failBuildOnCVSS=11`) **no prueban ausencia de vulnerabilidades**.
- Asociación CVE ≠ explotabilidad en una aplicación concreta.
- Log4j 2.17.1 fue comparador histórico frente a Log4Shell; con NVD a 2026-10-09
  mantiene 5 CVE posteriores: no presentarla como segura.
- Detalle de contratos, oráculo, semillas y comandos Maven por clase en el código
  (`experimento-didactico/src/`) y en los `README.md` de
  [`evidencias/resultados/`](evidencias/resultados/README.md).
