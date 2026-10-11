# Pruebas unitarias y de regresión (JUnit 5 + Surefire)

## Qué se evaluó

Regresión determinista de las dos variantes del resolvedor didáctico de plantillas,
sin fuzzing: **V-A** (`ResolutorPlantillas`, con reinterpretación deliberada del dato)
y **V-B** (`ResolutorPlantillasCorregido`, una sola pasada + límites de longitud).
Se ejecutaron las baterías escritas a mano: `ResolutorPlantillasTest` (V-A, 12 pruebas)
y `ResolutorPlantillasCorregidoTest` (V-B, 19 pruebas).

## Herramienta y comando

* Apache Maven 3.9.16, JDK 21.0.12.1, PowerShell 7.6.6, `maven-surefire-plugin` 3.6.0
  (versiones registradas en el manifiesto de la ejecución de origen).
* Comando relativo (desde la raíz del repositorio, directorio de trabajo
  `experimento-didactico/`):
  `mvn --batch-mode -Dtest=ResolutorPlantillasTest,ResolutorPlantillasCorregidoTest -Dsurefire.failIfNoSpecifiedTests=false test`

## Archivos incluidos

* `salida-estandar.log` — salida de Maven/Surefire sanitizada (rutas locales reemplazadas).
* `salida-error.log` — vacía en la ejecución de origen (0 bytes); se conserva por simetría.
* `reportes/edu.proyecto.calidad.plantillas.ResolutorPlantillasTest.txt` — resumen V-A.
* `reportes/edu.proyecto.calidad.plantillas.ResolutorPlantillasCorregidoTest.txt` — resumen V-B.
* `reportes/TEST-*.xml` — informes Surefire por clase (propiedades de entorno sanitizadas;
  casos, tiempos y resultados intactos).

## Fecha de la ejecución de origen

2026-10-11 (ejecución `20261011-134106`; ver `../TRAZABILIDAD.md`).

## Resultados

* V-A: `Tests run: 12, Failures: 0, Errors: 0, Skipped: 0`.
* V-B: `Tests run: 19, Failures: 0, Errors: 0, Skipped: 0`.
* Total: `Tests run: 31, Failures: 0, Errors: 0, Skipped: 0`, `BUILD SUCCESS`, código de salida 0.
* Verificación: líneas `Tests run` en `salida-estandar.log` y en los TXT de `reportes/`.

## Limitaciones

* Solo cubre los casos escritos a mano; no generaliza a otras entradas.
* La aprobación de todas las pruebas **no demuestra ausencia de defectos**.
* Una prueba de V-A (`reinterpretacionDeExpresionEnDato`, TEST-006) comprueba
  deliberadamente el comportamiento defectuoso (`Hola, ANA xyz`): documenta el defecto,
  no un comportamiento seguro. El hallazgo se reproduce de forma independiente en
  `../fuzzing-resolutor-plantillas/`.

## Origen y trazabilidad

Ejecución de origen `20261011-134106`, repetición equivalente `20261011-135743`
(mismas cifras 31/0/0; solo difieren tiempos de ejecución). Detalle de hashes y
sanitización en `../TRAZABILIDAD.md`.
