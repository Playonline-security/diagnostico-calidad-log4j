# Fuzzing del resolvedor de plantillas (V-A, variante vulnerable)

## Qué se evaluó

Fuzzing basado en semillas (regresión determinista, sin generación de entradas nuevas)
del resolvedor vulnerable **V-A** (`ResolutorPlantillas`), que reexpande el resultado
hasta punto fijo y por tanto reinterpreta expresiones aportadas por el dato no confiable.
No es Apache Log4j ni reproduce Log4Shell: las únicas funciones son operaciones locales
sobre cadenas (`minusculas`, `mayusculas`, `longitud`), sin red, JNDI, LDAP, RMI ni
ejecución de código.

## Herramienta y comando

* Apache Maven 3.9.16, JDK 21.0.12.1, `jazzer-junit` 0.30.0 vía
  `maven-surefire-plugin` 3.6.0, con
  `-DargLine=-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading`.
* Comando relativo (directorio de trabajo `experimento-didactico/`):
  `mvn --batch-mode -Dtest=ResolutorPlantillasFuzzTest "-DargLine=-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading" -Dsurefire.failIfNoSpecifiedTests=false test`
* Semillas fijadas en el código (`datosSemilla()`); esta corrida es regresión
  determinista (`JAZZER_FUZZ` no activado).

## Archivos incluidos

* `salida-estandar.log` — traza Maven/Surefire con el hallazgo (rutas sanitizadas).
* `salida-error.log` — ganchos (hooks) de Jazzer (rutas sanitizadas).
* `informe-fuzz-va.txt` — informe Surefire con la traza de HALL-001.
* `informe-fuzz-va.xml` — informe Surefire XML (propiedades de entorno sanitizadas).
* `entradas-reproduccion/` — los tres `crash-*` históricos (bytes exactos, sin modificar;
  ver `entradas-reproduccion/nota-entradas.md`).

## Fecha de la ejecución de origen

2026-10-11 (ejecución `20261011-134231`; ver `../TRAZABILIDAD.md`).

## Resultados

* `Tests run: 6, Failures: 0, Errors: 1, Skipped: 0` (`Time elapsed: 3.101 s`).
* Error: `FuzzTestFindingException` por `AssertionFailedError` del oráculo independiente:
  `expected:<Hola, ANA ${minusculas:XYZ}> but was:<Hola, ANA xyz>` con el dato
  `ana ${minusculas:XYZ}` (semilla de referencia).
* Este error es el hallazgo didáctico central **HALL-001** (la salida reinterpreta
  expresiones del dato), con código de salida 1 **esperado**. No es un fallo de
  infraestructura: el informe Surefire es fresco (`reporte_fresco: true` en el manifiesto
  original) y muestra la aserción esperada.

## Limitaciones

* Regresión determinista con las semillas existentes; no equivale a una sesión de
  fuzzing con generación prolongada ni generaliza a otras entradas.
* HALL-001 describe el componente didáctico; no demuestra nada sobre Apache Log4j.

## Origen y trazabilidad

Ejecución de origen `20261011-134231`, repetición equivalente `20261011-141357`
(mismas cifras 6/1; solo difiere el tiempo, 3.101 s frente a 2.776 s; mismos 3 `crash-*`
por SHA-256). Detalle en `../TRAZABILIDAD.md`.
