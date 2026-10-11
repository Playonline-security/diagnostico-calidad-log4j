# Evidencias públicas del diagnóstico de calidad

## Propósito

Esta carpeta contiene la vista pública, organizada por técnica, de las evidencias del
diagnóstico de calidad del software: un componente didáctico V-A/V-B inspirado en la
idea abstracta de Log4Shell (no reinterpretar el dato como instrucción) más el análisis
de composición de software sobre `log4j-core` real (2.14.1 afectada, 2.17.1 corregida).
Cada subcarpeta incluye los artefactos técnicos necesarios para verificar los resultados
y un `README.md` con resultados, limitaciones y procedencia.

> El componente V-A/V-B es didáctico y **no es el código fuente real de Apache Log4j**.
> El experimento no implementa ninguna explotación de Log4Shell (sin JNDI, LDAP, RMI,
> red ni ejecución dinámica de código).

## Organización

* `pruebas-unitarias/` — regresión JUnit de V-A (12) + V-B (19): 31/31 en verde.
* `fuzzing-resolutor-plantillas/` — fuzzing de V-A: 6 invocaciones, 1 error (HALL-001,
  salida esperada distinta de cero) + entradas de reproducción en `entradas-reproduccion/`.
* `fuzzing-resolutor-corregido/` — fuzzing de V-B: 7 invocaciones, 0 errores, salida 0,
  más ejecución histórica complementaria de ~94 s.
* `analisis-estatico/` — SpotBugs + Find Security Bugs: 0 hallazgos (3 clases) + XML
  histórico de V-A (1 clase).
* `analisis-dependencias/` — Dependency-Check **histórico del 9 de octubre de 2026**:
  12 asociaciones / 9 CVE (2.14.1) frente a 8 / 5 CVE (2.17.1), con informes HTML+JSON.
* `TRAZABILIDAD.md` — origen, fechas y SHA-256 de cada copia; sanitización aplicada;
  repeticiones comprobadas y omisiones justificadas.

## Resultados principales

* JUnit: 31 pruebas, 0 fallos (origen 2026-10-11).
* Fuzz V-A: HALL-001 reproducido (`expected:<Hola, ANA ${minusculas:XYZ}> but was:<Hola, ANA xyz>`).
* Fuzz V-B: 0 errores en regresión y en corrida histórica de ~94 s.
* SpotBugs: 0 instancias, 0 errores de análisis.
* Dependency-Check (histórico): 2.14.1 con 2 asociaciones críticas y 2 en CISA KEV;
  2.17.1 sin críticas pero con 5 CVE posteriores (no presentarla como segura).

## Limitaciones de interpretación

* Las pruebas, el fuzzing y el análisis estático aportan información complementaria;
  **un resultado sin hallazgos no demuestra ausencia de defectos**.
* La prueba TEST-006 de V-A documenta deliberadamente un comportamiento defectuoso.
* Las asociaciones CVE deben interpretarse en contexto; no equivalen a explotabilidad.
* Los informes de dependencias dependen de la base NVD a 2026-10-09.

## Referencias

* Trazabilidad: [`TRAZABILIDAD.md`](TRAZABILIDAD.md).
* Auditoría CVE: [`../../resultados-auditoria/auditoria_cve_dependency_check.md`](../../resultados-auditoria/auditoria_cve_dependency_check.md).
* Registros originales intactos: [`../ejecuciones/`](../ejecuciones/).
