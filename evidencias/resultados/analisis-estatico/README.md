# Análisis estático (SpotBugs + Find Security Bugs)

## Qué se evaluó

Análisis estático del componente didáctico con la configuración existente del proyecto
(SpotBugs + plugin Find Security Bugs), de forma conjunta sobre ambas variantes
en la ejecución actual.

## Herramienta y comando

* `spotbugs-maven-plugin` 4.8.3.1 + `findsecbugs-plugin` 1.14.0 (según `pom.xml`),
  motor SpotBugs 4.8.3, JDK 21.0.12.1.
* Comando relativo (directorio de trabajo `experimento-didactico/`):
  `mvn --batch-mode compile spotbugs:check`

## Archivos incluidos

* `salida-estandar.log` / `salida-error.log` — traza de la ejecución actual (rutas sanitizadas).
* `informe-spotbugs.xml` — informe XML actual: 3 clases analizadas (V-A, V-B y clase de
  demostración), `total_bugs='0'`, sin errores (rutas de proyecto sanitizadas; métricas intactas).
* `spotbugs-va-historico.xml` — informe histórico (2026-10-09): solo 1 clase (V-A),
  `total_bugs='0'`. Documenta la evolución del análisis (de 1 clase a 3 clases).

## Fecha de las ejecuciones

* Actual: 2026-10-11 (ejecución `20261011-133942`).
* Histórica: 2026-10-09 (`F-05`). Ver `../TRAZABILIDAD.md`.

## Resultados

* Actual: `BugInstance size is 0`, `Error size is 0`, `No errors/warnings found`,
  `BUILD SUCCESS`, código de salida 0.
* Histórico V-A: `total_bugs='0'`, 1 clase, mismo veredicto.
* El informe intermedio de 2 clases (`F-06B`, 2026-10-09, mismo veredicto) no se publica
  por redundante; queda referenciado en `../TRAZABILIDAD.md`.

## Limitaciones

* **Cero hallazgos no demuestra ausencia de vulnerabilidades**: V-A contiene la
  reinterpretación documentada (HALL-001) que este análisis genérico no detecta.
* Análisis con esfuerzo y umbral por defecto, sin filtros; otras configuraciones
  podrían variar el resultado.
* El histórico cubre solo V-A (1 clase); no es comparable directamente con el actual (3 clases).

## Origen y trazabilidad

Ejecución actual `20261011-133942`, repetición equivalente `20261011-141815`
(ambas `total_bugs='0'`; solo difiere `analysisTimestamp`). Histórico `F-05`.
Detalle en `../TRAZABILIDAD.md`.
