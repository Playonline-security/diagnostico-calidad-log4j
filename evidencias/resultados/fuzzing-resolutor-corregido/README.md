# Fuzzing del resolvedor corregido (V-B, variante corregida)

## Qué se evaluó

Fuzzing basado en semillas (regresión determinista, sin generación de entradas nuevas)
del resolvedor corregido **V-B** (`ResolutorPlantillasCorregido`): una sola pasada de
expansión (los valores del contexto quedan como texto literal) más límites de longitud
con rechazo explícito (`IllegalArgumentException`). Se comprueba la propiedad de no
reinterpretación con 6 semillas, incluida una larga de 10 001 caracteres.

## Herramienta y comando

* Apache Maven 3.9.16, JDK 21.0.12.1, `jazzer-junit` 0.30.0 vía Surefire, con
  `-DargLine=-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading`.
* Comando relativo (directorio de trabajo `experimento-didactico/`):
  `mvn --batch-mode -Dtest=ResolutorPlantillasCorregidoFuzzTest "-DargLine=-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading" -Dsurefire.failIfNoSpecifiedTests=false test`
* Esta corrida es regresión determinista (`JAZZER_FUZZ` no activado).

## Archivos incluidos

* `salida-estandar.log` / `salida-error.log` — traza de la ejecución canónica (rutas sanitizadas).
* `informe-fuzz-vb.txt` / `informe-fuzz-vb.xml` — informe Surefire canónico (entorno sanitizado).
* `informe-fuzz-vb-historico-90s.txt` / `.xml` — **ejecución histórica adicional**
  (2026-10-09, ~94 s con generación Jazzer): mismo veredicto con duración real de
  fuzzing prolongado. No confundir con la ejecución canónica.

## Fecha de las ejecuciones

* Canónica: 2026-10-11 (ejecución `20261011-134254`).
* Histórica complementaria: 2026-10-09 (`F-06B`, corrida con generación de ~90 s).
* Ver `../TRAZABILIDAD.md`.

## Resultados

* Canónica: `Tests run: 7, Failures: 0, Errors: 0, Skipped: 0` (`Time elapsed: 2.676 s`),
  `BUILD SUCCESS`, código de salida 0.
* Histórica: `Tests run: 7, Failures: 0, Errors: 0, Skipped: 0` (`Time elapsed: 94.00 s`).
* Ambas confirman la propiedad de no reinterpretación en su alcance. La histórica aporta
  la única evidencia de fuzzing con generación prolongada del repositorio.

## Limitaciones

* Alcance limitado a las semillas documentadas (incluida la larga con rechazo
  `IllegalArgumentException`); **cero errores no demuestra ausencia de defectos**
  ni equivale a una campaña de fuzzing exhaustiva.
* La corrida histórica usó el corpus y la configuración de octubre de 2026; sus tiempos
  no son comparables directamente con la regresión actual.

## Origen y trazabilidad

Ejecución canónica `20261011-134254`, repetición equivalente `20261011-141715`
(mismas cifras 7/0/0; 2.676 s frente a 2.620 s). Histórica `F-06B/surefire` (94 s).
Detalle en `../TRAZABILIDAD.md`.
