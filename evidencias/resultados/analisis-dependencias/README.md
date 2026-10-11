# Análisis de dependencias (OWASP Dependency-Check)

> **Resultados históricos del 9 de octubre de 2026.** No son un diagnóstico actualizado
> al momento de publicación: dependen de la base NVD y del momento del análisis.
> No se regeneraron ni se sincronizó NVD para esta publicación.

## Qué se evaluó

Análisis de composición de software (SCA) con OWASP Dependency-Check sobre dos
variantes reales de `log4j-core` (no sobre el componente didáctico V-A/V-B):

* **Afectada**: `log4j-core` 2.14.1 (vulnerable a Log4Shell, CVE-2021-44228).
* **Corregida**: `log4j-core` 2.17.1 (comparador histórico frente a Log4Shell).

Los POM son mínimos (solo declaran el artefacto y el plugin); el informe dice
“dependencia con CVE conocido”, nunca “explotable en contexto”. Para reproducir el
análisis, ver `analisis-log4j/afectada/pom.xml` y `analisis-log4j/corregida/pom.xml`
(`dependency-check-maven` 13.0.0, `failBuildOnCVSS=11`, formatos HTML+JSON).

## Archivos incluidos

* `log4j-2.14.1-afectada.html` / `.json` — informes históricos de la versión afectada
  (copias del 2026-10-09; solo se sanitizó la ruta local del repositorio Maven).
* `log4j-2.17.1-corregida.html` / `.json` — informes históricos de la versión corregida
  (ídem).
* `verificacion-local.log` — salida de la verificación local de los cuatro informes
  (conteos derivados del JSON y del HTML, sin red ni regeneración).

## Resultados comprobados contra los JSON

| Métrica | Log4j 2.14.1 | Log4j 2.17.1 |
|---|---:|---:|
| Dependencias analizadas | 2 | 2 |
| Asociaciones de vulnerabilidad | 12 (`log4j-api` 3 + `log4j-core` 9) | 8 (`log4j-api` 3 + `log4j-core` 5) |
| CVE únicos | 9 | 5 |
| Asociaciones críticas (CVSS v3.1 ≥ 9) | 2 (CVE-2021-44228 CVSS 10, CVE-2021-45046 CVSS 9) | 0 |
| Asociaciones presentes en CISA KEV | 2 (CVE-2021-44228, CVE-2021-45046) | 0 |

* Los HTML confirman `Vulnerabilities Found: 12 / 8`.
* Cuatro CVE de 2021 presentes en 2.14.1 **no aparecen** en el informe de 2.17.1:
  CVE-2021-44228, CVE-2021-45046, CVE-2021-44832 y CVE-2021-45105. Esta observación se
  limita a la comparación de estos informes históricos.
* La versión 2.17.1 mantiene 5 CVE posteriores (2025/2026) con NVD a 2026-10-09:
  **no describirla como universalmente segura ni como la versión más reciente**.
* Nota CVSS: las puntuaciones citadas son CVSS v3.1 del JSON (`cvssv3.baseScore`);
  el resumen HTML puede mostrar otra versión de la métrica para el mismo CVE.

## Limitaciones

* Asociación CVE ≠ explotabilidad en una aplicación concreta (POMs mínimos sin
  aplicación ni configuración).
* Base NVD a 2026-10-09; con otra fecha los CVE 2025/2026 podrían variar.
* `failBuildOnCVSS=11` implica que el análisis registra observaciones sin fallar
  la construcción aunque haya CVE.

## Origen y trazabilidad

Informes originales en `analisis-log4j/*/target/` (2026-10-09 10:57 y 11:06).
Verificación local `20261011-134115` (revalidada en `20261011-134604` y
`20261011-141919` con conteos idénticos). Auditoría de los 9 CVE en
`resultados-auditoria/auditoria_cve_dependency_check.md`. Detalle en
`../TRAZABILIDAD.md`.
