# Entradas de reproducción (HALL-001)

Los tres archivos `crash-*` son entradas Jazzer históricas (octubre de 2026) copiadas
**byte a byte, sin modificar** (SHA-256 en `../TRAZABILIDAD.md`, idénticos a
`evidencias/F-06B/crash/`). Son blobs binarios serializados de Jazzer (prefijo de
longitud + bytes de la entrada); no contienen información sensible, solo fragmentos
de plantillas.

* `crash-cb654aade3384a45060315cb2a4e6e0ae660fb36` (26 B) — contiene la semilla canónica
  de HALL-001, `ana ${minusculas:XYZ}`.
* `crash-e031d2ec36a99fb1f80fa91375f7372417d3ec0b` (20 B) — variante con la semilla
  `ana ${girar:…}` (función desconocida, queda literal).
* `crash-c9a82928cb9115f07860220d419a57587f1e02ab` (213 B) — entrada compuesta con
  varias secuencias `${…}` anidadas.

Se conservan los tres porque documentan la semilla del hallazgo y sus variantes, y
porque la ejecución de origen los incluía como artefactos. No se publica el corpus
completo (656 entradas en `.cifuzz-corpus/`, local): volumen alto y solo se necesita
el conteo, registrado en el manifiesto original.
