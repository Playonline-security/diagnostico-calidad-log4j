# Auditoría técnica de vulnerabilidades detectadas por OWASP Dependency-Check

**Proyecto:** diagnóstico de calidad — comparación Log4j 2.14.1 (afectada) vs 2.17.1 (corregida)
**Herramienta auditada:** OWASP Dependency-Check Maven Plugin `13.0.0`
**Fecha de generación de informes auditados:** 2026-10-09
**Fecha de auditoría documental:** 2026-10-10
**Evidencias locales:** `analisis-log4j/` (no modificadas)
**Documento:** `resultados-auditoria/auditoria_cve_dependency_check.md`

> Convención usada en todo el documento:
> - **Observado por la herramienta** = lo que dicen los HTML/JSON locales.
> - **Confirmado por fuente oficial** = verificado en NVD / Apache Logging Services / CISA / GHSA el 2026-10-10.
> - **Interpretación técnica** = juicio del auditor, etiquetado con nivel de certeza.

---

## 1. Alcance y método de auditoría

### 1.1 Alcance

1. Determinar qué vulnerabilidades identificó Dependency-Check en cada versión.
2. Determinar cuáles desaparecen de 2.14.1 a 2.17.1 y cuáles persisten.
3. Establecer condiciones técnicas de aplicabilidad de cada CVE.
4. Evaluar indicios de falsos positivos o asociaciones excesivamente amplias (en particular CVE-2026-34479, CVE-2026-34480, CVE-2026-49844).
5. Distinguir afirmaciones sustentables con evidencia local de las que requieren validación externa.

No se ejecutaron exploits ni pruebas destructivas. No se regeneraron informes. No se modificó `analisis-log4j/`.

### 1.2 Método

1. **Inspección local (solo lectura):**
   - `analisis-log4j/afectada/pom.xml`, `analisis-log4j/corregida/pom.xml`.
   - `analisis-log4j/afectada/target/dependency-check-report.html` y `.json`.
   - `analisis-log4j/corregida/target/dependency-check-report.html` y `.json`.
   - Contraste HTML vs JSON campo a campo; las discrepancias se documentan, no se resuelven silenciosamente.
2. **Validación documental externa (2026-10-10):**
   - Fuente primaria preferente: `https://logging.apache.org/log4j/2.x/security.html` y `https://logging.apache.org/security.html`.
   - `https://nvd.nist.gov/vuln/detail/<CVE>`, `https://www.cve.org/CVERecord?id=<CVE>`.
   - `https://github.com/advisories/<GHSA>` para mapeo Maven `groupId:artifactId`.
   - CISA KEV: catálogo web y entradas `AA21-356A`.
3. **Criterio de certeza por CVE:** `confirmado` / `probable` / `indeterminado` / `no aplicable`. Un falso positivo solo se declara confirmado con evidencia de código o declaración oficial de no-afectación del artefacto exacto; en caso contrario se habla de **asociación excesiva probable**.

### 1.3 Verificación de la tabla preliminar

| Indicador | Preliminar 2.14.1 | Preliminar 2.17.1 | Veredicto auditoría |
|---|---:|---:|---|
| Dependencias analizadas | 2 | 2 | **Correcto.** HTML `Dependencies Scanned: 2 (2 unique)` en ambos; JSON `dependencies.length == 2` en ambos. |
| Dependencias vulnerables | 2 | 2 | **Correcto.** HTML `Vulnerable Dependencies: 2` en ambos. |
| Asociaciones dependencia–CVE | 12 | 8 | **Correcto.** HTML `Vulnerabilities Found: 12 / 8`; JSON `3+9=12`, `3+5=8`. |
| CVE únicos | 9 | 5 | **Correcto.** Deduplicación de `vulnerabilities[].name` (ver §3). |
| CVE críticos | 2 | 0 | **Correcto** si “crítico” = CVSSv3 `baseSeverity == CRITICAL`. Son CVE-2021-44228 (10.0) y CVE-2021-45046 (9.0), ambos solo en 2.14.1. |
| En CISA KEV | 2 | 0 | **Correcto.** JSON `knownExploitedVulnerability` presente solo en esos 2; HTML `CRITICAL*` + `CISA Known Exploited Vulnerability` solo en 2.14.1; catálogo CISA lista ambos. |

---

## 2. Inventario de archivos y versiones analizadas

### 2.1 Archivos inspeccionados

| Ruta (relativa al repo) | Tamaño aprox. | Tipo / rol |
|---|---|---|
| `analisis-log4j/afectada/pom.xml` | ~2,0 KB | POM mínimo EXP-REAL-A. Declara `org.apache.logging.log4j:log4j-core:2.14.1` y plugin `org.owasp:dependency-check-maven:13.0.0` con formatos HTML+JSON y `failBuildOnCVSS=11`. Solo referencia `nvdApiServerId=nvd-api-key`, sin secretos. |
| `analisis-log4j/afectada/target/dependency-check-report.html` | ~529,6 KB | Evidencia HTML 2.14.1. |
| `analisis-log4j/afectada/target/dependency-check-report.json` | ~267,7 KB | Evidencia JSON 2.14.1 (`reportSchema 1.1`). |
| `analisis-log4j/corregida/pom.xml` | ~2,0 KB | POM mínimo EXP-REAL-B. Idéntico salvo `log4j-core:2.17.1` y `artifactId`. |
| `analisis-log4j/corregida/target/dependency-check-report.html` | ~201,4 KB | Evidencia HTML 2.17.1. |
| `analisis-log4j/corregida/target/dependency-check-report.json` | ~85,7 KB | Evidencia JSON 2.17.1. |

No hay logs, imágenes, suppression XML, scripts ni notas de validación dentro de `analisis-log4j/`. No hay duplicados exactos ni temporales. `target/` es salida Maven regenerable.

> Nota de privacidad: los HTML/JSON incluyen la ruta local del repositorio Maven (`<user-home>/.m2/repository/...`) y hashes MD5/SHA1/SHA256. En este documento se omiten las rutas absolutas. No se encontró ninguna API key, token o contraseña en `analisis-log4j/`.

> Nota de versionado: el `.gitignore` del repo ignora `target/`, por lo que los 4 reportes están actualmente excluidos de Git por defecto. Ver §8 y §9.

### 2.2 Versiones exactas y relación directa/transitiva

Ambos POM declaran **solo** `log4j-core` como dependencia directa. `log4j-api` aparece únicamente como transitiva traída por Core.

| Proyecto | `log4j-core` (directa) | `log4j-api` (transitiva) | Evidencia |
|---|---|---|---|
| `afectada` | `2.14.1`, `pkg:maven/org.apache.logging.log4j/log4j-core@2.14.1`, SHA1 `9141212b...`, CPE `cpe:2.3:a:apache:log4j:2.14.1:*`, confianza `Highest`, Evidence 46 | `2.14.1`, `pkg:maven/.../log4j-api@2.14.1`, SHA1 `cd8858fb...`, mismo CPE base, confianza `Highest`, Evidence 42 | HTML `Referenced In Project/Scope: ...:compile` en ambas; `Included by: pkg:maven/edu.proyecto.calidad/analisis-log4j-afectada@0.1.0` (core = directa) vs `Included by: pkg:maven/org.apache.logging.log4j/log4j-core@2.14.1` + tooltip “is in the transitive dependency tree” (api = transitiva). JSON `projectReferences: [...:compile]` en ambas (no distingue; la distinción es solo HTML). |
| `corregida` | `2.17.1`, `pkg:maven/.../log4j-core@2.17.1`, SHA1 `779f60f3...`, CPE `cpe:2.3:a:apache:log4j:2.17.1:*`, `Highest`, Evidence 48 | `2.17.1`, `pkg:maven/.../log4j-api@2.17.1`, SHA1 `d771af8e...`, mismo CPE base, `Highest`, Evidence 44 | Mismo patrón HTML con `analisis-log4j-corregida@0.1.0` y `log4j-core@2.17.1` como inclusores. |

### 2.3 Fechas, fuentes y supresiones (observado)

- Motor: `dependency-check version 13.0.0` (HTML Scan Information + JSON `scanInfo.engineVersion`).
- Generación: afectada `Fri, 9 Oct 2026 10:57:12 -0500` (`reportDate 2026-10-09T15:57:12Z`); corregida `Fri, 9 Oct 2026 11:06:30 -0500` (`reportDate 2026-10-09T16:06:31Z`).
- NVD: `NVD API Last Checked 2026-10-09T10:41:38-05`, `NVD API Last Modified 2026-10-09T15:31:26Z` (ambos).
- Fuente de cada CVE en JSON: `source: NVD` en los 20 registros (12+8).
- Supresiones: `Vulnerabilities Suppressed: 0` en ambos HTML; `suppressedVulnerabilities: []` en las 4 dependencias JSON. **No hay filtrado.**
- CWE, CPE y referencias presentes por CVE (detalle en §5). Ejemplo: CVE-2021-44228 con 103 referencias y 351 entradas `vulnerableSoftware` en JSON; CVE 2026 con 4–8 referencias y 6–7 entradas.

### 2.4 Discrepancias HTML vs JSON (documentadas, no ocultadas)

1. **Campo `severity` vs `cvssv3.baseSeverity` en CVE 2026-34479 y 2026-34480.** JSON trae ambos: `severity: MEDIUM` pero `cvssv3.baseScore 7.5 / baseSeverity HIGH` (CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:H/A:N). La tabla Summary HTML muestra `Highest Severity: MEDIUM` para `log4j-api-2.14.1`, `log4j-api-2.17.1` y `log4j-core-2.17.1`, aunque su JSON contiene un 7.5 HIGH. Solo `log4j-core-2.14.1` muestra `CRITICAL*` (por CVE-2021-44228). **Interpretación:** el HTML parece ordenar por `severity`, no por `cvssv3.baseSeverity`. En esta auditoría se cita siempre la métrica con versión (p. ej. “CVSSv3.1 7.5 HIGH; campo `severity` NVD MEDIUM”) y se usa CVSSv3 como referencia de criticidad.
2. **Rango de CVE-2021-44832.** JSON NVD: `2.13.0–2.17.1` (excl. `2.17.1`). Apache Security (consultado 2026-10-10): afectado `[2.0-beta7, 2.3.1) ∪ [2.4, 2.12.3) ∪ [2.13.0, 2.17.0)`, corregido en `2.3.1 / 2.12.3 / 2.17.0`; la descripción NVD del propio JSON dice corregido en `2.17.1 / 2.12.4 / 2.3.2`. La diferencia (`2.17.0` vs `2.17.1`) no altera el veredicto (2.14.1 afectada, 2.17.1 no), pero se deja constancia.
3. **CVSS 4.0 ausente en JSON.** Los JSON solo traen `cvssv3` (+ `cvssv2` en los 4 CVE de 2021). Apache publica además CVSS 4.0 (p. ej. 6.9/6.3 MEDIUM en los CVE 2025/2026). No es contradicción, es cobertura parcial del escáner a fecha 2026-10-09. Se citan ambas cuando existen.

---

## 3. Resultados originales de Dependency-Check

### 3.1 Proyecto afectada (2.14.1) — observado

- `Dependencies Scanned: 2 (2 unique)`, `Vulnerable: 2`, `Found: 12`.
- `log4j-api-2.14.1.jar`: 3 CVE → CVE-2026-34479, CVE-2026-34477, CVE-2026-49844.
- `log4j-core-2.14.1.jar`: 9 CVE → CVE-2021-44228 (10.0 CRITICAL, KEV), CVE-2021-45046 (9.0 CRITICAL, KEV), CVE-2026-34479 (7.5 HIGH), CVE-2026-34480 (7.5 HIGH), CVE-2021-44832 (6.6 MEDIUM), CVE-2025-68161 (4.8 MEDIUM), CVE-2026-34477 (5.9 MEDIUM), CVE-2026-49844 (5.9 MEDIUM), CVE-2021-45105 (5.9 MEDIUM).
- CVE únicos: **9**. KEV: **2**. Suprimidos: 0.

### 3.2 Proyecto corregida (2.17.1) — observado

- `Dependencies Scanned: 2 (2 unique)`, `Vulnerable: 2`, `Found: 8`.
- `log4j-api-2.17.1.jar`: 3 CVE → CVE-2026-34479, CVE-2026-34477, CVE-2026-49844 (idénticos ID que en api 2.14.1).
- `log4j-core-2.17.1.jar`: 5 CVE → CVE-2026-34479, CVE-2026-34480, CVE-2025-68161, CVE-2026-34477, CVE-2026-49844.
- CVE únicos: **5**. KEV: **0**. Suprimidos: 0.
- Desaparecen respecto a 2.14.1: CVE-2021-44228, CVE-2021-45046, CVE-2021-44832, CVE-2021-45105. Ningún CVE nuevo aparece solo en 2.17.1.

### 3.3 CPE usado por la herramienta (causa raíz de §6)

Todos los registros usan el CPE genérico `cpe:2.3:a:apache:log4j:*` (sin sufijo de módulo), p. ej. `cpe:2.3:a:apache:log4j:2.14.1:*`. El `packageUrl` sí distingue `log4j-api` vs `log4j-core`, pero la coincidencia NVD se hace contra el producto genérico `a:apache:log4j`. Esto explica asignaciones cruzadas (§6).

---

## 4. Tabla consolidada de CVE únicos

Leyenda: `SÍ` = presente en el informe local de esa versión. CVSS = CVSSv3.1 NVD observado en JSON (se indica si Apache añade CVSS 4.0). Validación = resultado de §5.

| CVE | Componente asociado por DC | Presente en 2.14.1 | Presente en 2.17.1 | CVSS / severidad (observado) | Condiciones de aplicabilidad (fuente oficial) | Validación documental |
|---|---|---|---|---|---|---|
| CVE-2021-44228 (Log4Shell) | `log4j-core` (directa) | SÍ | NO | CVSSv3.1 10.0 CRITICAL | Mensaje/parámetro/config controlados por atacante con JNDI/LDAP y sustitución de lookups habilitada | **Confirmado.** Afecta 2.14.1, no 2.17.1. KEV sí. Coincide con oficial (solo core). |
| CVE-2021-45046 | `log4j-core` (directa) | SÍ | NO | CVSSv3.1 9.0 CRITICAL | MDC controlable + Pattern Layout no por defecto con Context Lookup / `%X/%mdc/%MDC` + JNDI | **Confirmado.** Afecta 2.14.1, no 2.17.1. KEV sí. Solo core. |
| CVE-2021-44832 | `log4j-core` (directa) | SÍ | NO | CVSSv3.1 6.6 MEDIUM (CVSSv2 8.5 HIGH) | JDBC Appender + URI JNDI LDAP + atacante controla servidor LDAP; requiere privilegios altos (PR:H) y configuración del operador | **Confirmado.** Afecta 2.14.1, no 2.17.1. KEV no. Solo core. |
| CVE-2021-45105 | `log4j-core` (directa) | SÍ | NO | CVSSv3.1 5.9 MEDIUM | MDC controlable + lookup autorreferencial recursivo → DoS | **Confirmado.** Afecta 2.14.1, no 2.17.1. KEV no. Solo core. |
| CVE-2025-68161 | `log4j-core` (directa) | SÍ | SÍ | CVSSv3.1 4.8 MEDIUM (Apache CVSS4 6.3 MEDIUM) | Socket Appender + TLS + MITM con cert de CA confiable (trust store configurado o JRE) | **Confirmado.** Afecta ambas. KEV no. Solo core; DC lo asigna solo a core (correcto). |
| CVE-2026-34477 | `log4j-api` (trans.) + `log4j-core` (dir.) | SÍ (ambos JAR) | SÍ (ambos JAR) | CVSSv3.1 5.9 MEDIUM (CVSS4 6.3 MEDIUM) | SMTP/Socket/Syslog + `<Ssl>` con `verifyHostName` ignorado + MITM con cert confiable; HTTP appender no afectado | **Confirmado para core; asociación excesiva probable para api.** Oficial: solo `Log4j Core`. |
| CVE-2026-34479 | `log4j-api` (trans.) + `log4j-core` (dir.) | SÍ (ambos JAR) | SÍ (ambos JAR) | CVSSv3.1 7.5 HIGH, campo `severity` MEDIUM (Apache CVSS4 6.9 MEDIUM) | Uso de `Log4j1XmlLayout` directo o capa compat. Log4j 1 con `org.apache.log4j.xml.XMLLayout` + caracteres prohibidos XML 1.0 en contenido | **Asociación excesiva probable en ambos JAR.** Oficial: solo `log4j-1.2-api` (puente, no declarado en los POM). |
| CVE-2026-34480 | `log4j-core` (directa) | SÍ | SÍ | CVSSv3.1 7.5 HIGH, campo `severity` MEDIUM (CVSS4 6.9 MEDIUM) | Uso de `XmlLayout` de Core + mensaje/MDC con caracteres prohibidos XML 1.0 (pérdida de evento según StAX) | **Confirmado.** Afecta ambas. Solo core; DC lo asigna solo a core (correcto). La sospecha preliminar de asociación a `api` no se materializa en los informes. |
| CVE-2026-49844 | `log4j-api` (trans.) + `log4j-core` (dir.) | SÍ (ambos JAR) | SÍ (ambos JAR) | CVSSv3.1 5.9 MEDIUM (CVSS4 6.3 MEDIUM) | `JsonTemplateLayout` con resolver `message` (u otro layout vía `MapMessage.asJson()`/`getFormattedMessage(JSON)`) + `MapMessage` con flotante no finito (`NaN`/`Infinity`) controlable | **Confirmado para api; asociación excesiva probable para core.** Oficial: solo `log4j-api`. |

Ningún CVE aparece únicamente en 2.17.1. Los 4 que desaparecen son exactamente el clúster 2021 corregido antes de 2.17.1/2.17.0.

---

## 5. Validación documental individual de los CVE

Fuentes consultadas el 2026-10-10 (URLs completas en §10). Las descripciones están redactadas con palabras propias.

### 5.1 CVE-2021-44228 — Log4Shell

1. **Identificador:** CVE-2021-44228.
2. **Componente oficial:** `log4j-core` únicamente. Apache: “only the `log4j-core` JAR file is impacted”.
3. **Versiones:** Afectadas `[2.0-beta9, 2.3.1) ∪ [2.4, 2.12.2) ∪ [2.13.0, 2.15.0)`; corregidas `2.3.1 / 2.12.2 / 2.15.0`. Por tanto 2.14.1 afectada, 2.17.1 no afectada.
4. **CVSS:** CVSSv3.1 10.0 CRITICAL (AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H), CVSSv2 9.3 HIGH. Coincide con JSON local.
5. **Descripción:** RCE por JNDI: datos controlables que llegan a mensajes, parámetros o configuración disparan resolución LDAP/JNDI y carga de código remoto.
6. **Condiciones:** atacante controla el texto registrado o sus parámetros; sustitución de lookups habilitada (por defecto en la rama afectada).
7. **KEV:** **Sí.** `Date Added 2021-12-10`, JSON local `knownExploitedVulnerability` presente, HTML `CISA Known Exploited Vulnerability` + `CRITICAL*`.
8. **Coincidencia DC:** **Sí.** DC lo reporta solo en `log4j-core-2.14.1.jar`, ausente en 2.17.1. Correcto.
9. **Fuentes y fecha:** Apache Security + NVD + CISA KEV, 2026-10-10.
10. **Certeza:** **confirmado.**

### 5.2 CVE-2021-45046

1. **Identificador:** CVE-2021-45046.
2. **Componente:** `log4j-core` únicamente (“Only ... `log4j-core` ... Applications using only `log4j-api` ... are not impacted”).
3. **Versiones:** `[2.0-beta9, 2.3.1) ∪ [2.4, 2.12.3) ∪ [2.13.0, 2.16.0)`; corregidas `2.3.1 / 2.12.3 / 2.16.0`. 2.14.1 afectada, 2.17.1 no.
4. **CVSS:** CVSSv3.1 9.0 CRITICAL (AV:N/AC:H/PR:N/UI:N/S:C/...), CVSSv2 5.1 MEDIUM. Coincide con JSON.
5. **Descripción:** El arreglo de 2.15.0 quedó incompleto en configuraciones no por defecto; el Thread Context Lookup permite fuga y RCE local/en ciertos entornos remota.
6. **Condiciones:** Pattern Layout no por defecto con `$${ctx:...}` o `%X/%mdc/%MDC` **y** MDC controlable por atacante.
7. **KEV:** **Sí** (catálogo CISA + JSON local).
8. **Coincidencia DC:** **Sí**, solo en core 2.14.1.
9. **Fuentes y fecha:** Apache + NVD + CISA, 2026-10-10.
10. **Certeza:** **confirmado.**

### 5.3 CVE-2021-44832

1. **Identificador:** CVE-2021-44832.
2. **Componente:** `log4j-core`.
3. **Versiones:** Apache: `[2.0-beta7, 2.3.1) ∪ [2.4, 2.12.3) ∪ [2.13.0, 2.17.0)`, corregidas `2.3.1 / 2.12.3 / 2.17.0`; NVD/JSON: `2.0.1–2.3.2 / 2.4–2.12.4 / 2.13.0–2.17.1`, texto “fixed ... 2.17.1, 2.12.4, 2.3.2”. Discrepancia menor documentada; ambas dejan 2.14.1 dentro y 2.17.1 fuera.
4. **CVSS:** CVSSv3.1 6.6 MEDIUM (AV:N/AC:H/PR:H/...), CVSSv2 8.5 HIGH. Coincide con JSON.
5. **Descripción:** RCE cuando el JDBC Appender resuelve un origen JNDI-LDAP bajo control del atacante; el arreglo limita los nombres JNDI al protocolo `java`.
6. **Condiciones:** usar JDBC Appender con URI JNDI-LDAP **+** atacante controla el servidor LDAP **+** atacante con privilegios de configuración (PR:H, configuración del operador, fuente confiable según modelo de amenaza Apache).
7. **KEV:** No (ausente en catálogo y en JSON).
8. **Coincidencia DC:** Sí en cuanto a versión/componente (solo core 2.14.1). La aplicabilidad real en estos POM mínimos es **indeterminada** (no hay configuración).
9. **Fuentes y fecha:** Apache + NVD, 2026-10-10.
10. **Certeza:** **confirmado** en versión/componente; aplicabilidad contextual **indeterminada**.

### 5.4 CVE-2021-45105

1. **Identificador:** CVE-2021-45105.
2. **Componente:** `log4j-core`.
3. **Versiones:** `[2.0-alpha1, 2.3.1) ∪ [2.4, 2.12.3) ∪ [2.13.0, 2.17.0)`, corregidas `2.3.1 / 2.12.3 / 2.17.0`. 2.14.1 afectada, 2.17.1 no.
4. **CVSS:** CVSSv3.1 5.9 MEDIUM (AV:N/AC:H/.../A:H), CVSSv2 4.3 MEDIUM. Coincide con JSON.
5. **Descripción:** DoS por recursión no controlada ante lookups autorreferenciales.
6. **Condiciones:** atacante controla datos de Thread Context Map interpretados como lookup.
7. **KEV:** No en catálogo (aunque el aviso conjunto AA21-356A menciona escaneos; no equivale a inclusión KEV).
8. **Coincidencia DC:** Sí (solo core 2.14.1).
9. **Fuentes y fecha:** Apache + NVD + CISA AA21-356A, 2026-10-10.
10. **Certeza:** **confirmado.**

### 5.5 CVE-2025-68161

1. **Identificador:** CVE-2025-68161.
2. **Componente:** Log4j Core (`org.apache.logging.log4j:log4j-core` en GHSA).
3. **Versiones:** `[2.0-beta9, 2.25.3)`, corregida `2.25.3`. Ambas 2.14.1 y 2.17.1 afectadas.
4. **CVSS:** NVD CVSSv3.1 4.8 MEDIUM (AV:N/AC:H/.../C:L/I:L/A:N); Apache CVSS4.0 6.3 MEDIUM. Coincide con JSON (4.8 MEDIUM, CWE-295/297).
5. **Descripción:** El Socket Appender omite la verificación de hostname TLS aunque se configure `verifyHostName`/`log4j2.sslVerifyHostName`.
6. **Condiciones:** Socket Appender con TLS **+** atacante en red capaz de interceptar/redirigir **+** cert de CA confiable por el trust store.
7. **KEV:** No.
8. **Coincidencia DC:** Sí. DC lo asigna solo a core en ambas versiones, coherente con GHSA `log4j-core`.
9. **Fuentes y fecha:** Apache + NVD + GHSA `GHSA-vc5p-v9hr-52mj`, 2026-10-10.
10. **Certeza:** **confirmado.**

### 5.6 CVE-2026-34477

1. **Identificador:** CVE-2026-34477.
2. **Componente:** Log4j Core.
3. **Versiones:** `[2.12.0, 2.25.4)`, corregida `2.25.4`. Ambas afectadas.
4. **CVSS:** CVSSv3.1 5.9 MEDIUM (AV:N/AC:H/...), CVSS4.0 6.3 MEDIUM. Coincide con JSON.
5. **Descripción:** El arreglo de CVE-2025-68161 solo cubrió la propiedad de sistema; el atributo `verifyHostName` del `<Ssl>` siguió ignorado, dejando TLS expuesto a MITM.
6. **Condiciones:** SMTP/Socket/Syslog con `<Ssl>` + MITM con cert confiable; HTTP appender no afectado (atributo distinto, verifica por defecto).
7. **KEV:** No.
8. **Coincidencia DC:** **Parcial.** Correcta para `log4j-core`; **excesiva para `log4j-api`** (oficial solo Core; el POM ni siquiera usa appenders TLS). Ver §6.
9. **Fuentes y fecha:** Apache + NVD (publicado 2026-04-10), 2026-10-10.
10. **Certeza:** **confirmado (core) / probable excesiva (api).**

### 5.7 CVE-2026-34479

1. **Identificador:** CVE-2026-34479.
2. **Componente:** `log4j-1.2-api` (puente Log4j 1→2). GHSA: `org.apache.logging.log4j:log4j-1.2-api`.
3. **Versiones:** `[2.7, 2.25.4)`, corregida `2.25.4`. Ambas 2.14.1/2.17.1 dentro del rango CPE, pero el artefacto afectado no es `api`/`core`.
4. **CVSS:** CVSSv3.1 7.5 HIGH (AV:N/AC:L/.../I:H), CVSS4.0 6.9 MEDIUM; JSON además trae `severity: MEDIUM` (origen de la discrepancia §2.4). CWE-116.
5. **Descripción:** `Log4j1XmlLayout` no escapa caracteres prohibidos XML 1.0 y genera XML malformado que los parsers deben rechazar (pérdida de eventos).
6. **Condiciones:** usar `Log4j1XmlLayout` en configuración Core 2 **o** capa compat. Log4j 1 con `org.apache.log4j.xml.XMLLayout` **+** contenido con caracteres prohibidos.
7. **KEV:** No.
8. **Coincidencia DC:** **No.** DC lo asigna a `log4j-api` y `log4j-core` en ambas versiones; ninguno de los POM declara `log4j-1.2-api`. Es el caso más claro de CPE genérico. Ver §6.
9. **Fuentes y fecha:** Apache + NVD (2026-04-10) + GHSA `GHSA-h383-gmxw-35v2`, 2026-10-10.
10. **Certeza:** **asociación excesiva probable (no se declara falso positivo confirmado sin análisis de código, ver §6).**

### 5.8 CVE-2026-34480

1. **Identificador:** CVE-2026-34480.
2. **Componente:** Log4j Core (`org.apache.logging.log4j:log4j-core` en GHSA `GHSA-3pxv-7cmr-fjr4`).
3. **Versiones:** `[2.0-alpha1, 2.25.4)`, corregida `2.25.4`. Ambas afectadas.
4. **CVSS:** CVSSv3.1 7.5 HIGH, CVSS4.0 6.9 MEDIUM; JSON `severity: MEDIUM`. CWE-116.
5. **Descripción:** `XmlLayout` de Core no sanea caracteres prohibidos XML 1.0; según StAX (JRE vs Woodstox) hay XML malformado o excepción con pérdida del evento.
6. **Condiciones:** usar `XmlLayout` **+** mensaje/MDC con caracteres prohibidos.
7. **KEV:** No.
8. **Coincidencia DC:** **Sí.** DC lo asigna solo a `log4j-core` en ambas versiones, nunca a `api`. La sospecha preliminar de asociación a `api` **no se confirma en los informes**: es un ejemplo de atribución correcta pese al CPE genérico.
9. **Fuentes y fecha:** Apache + NVD + GHSA, 2026-10-10.
10. **Certeza:** **confirmado.**

### 5.9 CVE-2026-49844

1. **Identificador:** CVE-2026-49844.
2. **Componente:** `log4j-api` (Apache: “Components affected `log4j-api`”; NVD `product Apache Log4j API`, `packageName org.apache.logging.log4j:log4j-api`).
3. **Versiones:** `[2.13.1, 2.25.5) ∪ [2.26.0, 2.26.1)`, corregidas `2.25.5 / 2.26.1`. Ambas 2.14.1/2.17.1 afectadas.
4. **CVSS:** CVSSv3.1 5.9 MEDIUM, CVSS4.0 6.3 MEDIUM. CWE-116. Coincide con JSON.
5. **Descripción:** `MapMessage.asJson()` emite `NaN`/`Infinity` sin entrecomillar, incumpliendo RFC 8259; resto del arreglo incompleto de CVE-2026-34481.
6. **Condiciones:** `JsonTemplateLayout` con resolver `message` (o cualquier layout vía `asJson()`/`getFormattedMessage(JSON)`) **+** `MapMessage` con flotante no finito controlable.
7. **KEV:** No.
8. **Coincidencia DC:** **Parcial.** Correcta para `log4j-api`; **excesiva para `log4j-core`** (oficial solo api). Ver §6.
9. **Fuentes y fecha:** Apache + NVD (2026-07-10) + OSV, 2026-10-10.
10. **Certeza:** **confirmado (api) / probable excesiva (core).**

---

## 6. Análisis de posibles falsos positivos y asociaciones excesivas

### 6.1 Mecanismo común: CPE genérico

**Observado:** los 20 registros JSON usan `cpe:2.3:a:apache:log4j:*` sin calificador de módulo. **Confirmado externamente:** NVD y OSV usan el mismo CPE genérico para los 9 CVE, mientras que Apache y GHSA distinguen el artefacto Maven (`log4j-core` / `log4j-api` / `log4j-1.2-api`).

**Interpretación (probable):** Dependency-Check hereda la granularidad NVD y propaga el CVE a todo JAR cuyo `evidence` resuelva al producto `a:apache:log4j`, aunque el defecto viva en otro módulo. No es un error de versión (los rangos sí incluyen 2.14.1/2.17.1 cuando corresponde), sino de **módulo**.

### 6.2 Caso por caso

| Caso preliminar | Lo que muestran los informes | Lo que dice la fuente oficial | Veredicto |
|---|---|---|---|
| CVE-2026-34479 en `core`/`api` | Presente en los 4 JAR (api+core × 2 versiones) | Solo `log4j-1.2-api` (GHSA `log4j-1.2-api >=2.7, <2.25.4`). Ningún POM declara ese artefacto. | **Asociación excesiva probable en los 4.** No se declara FP confirmado porque haría falta (a) inspeccionar si `core` embebe la clase o (b) declaración oficial de no-afectación de `core`/`api`. Evidencia adicional necesaria: `mvn dependency:tree`, presencia de `Log4j1XmlLayout.class` en los JAR, o suppression con justificación. |
| CVE-2026-34480 en `api` | **No presente en `api` en ningún informe** (solo en `core` 2.14.1 y 2.17.1) | Solo `log4j-core` | **Sospecha preliminar refutada.** Es una atribución correcta; citar como ejemplo de que el CPE genérico no siempre contamina. |
| CVE-2026-49844 en `core` | Presente en `core` + `api` en ambas versiones | Solo `log4j-api` | **Correcta en `api`; excesiva probable en `core`.** Misma evidencia adicional requerida que arriba (árbol de dependencias, uso de `MapMessage`, suppression). |
| CVE-2026-34477 en `api` | Presente en `api` + `core` | Solo `Log4j Core` (SMTP/Socket/Syslog + TLS) | **Correcta en `core`; excesiva probable en `api`.** Agravante: los POM mínimos ni siquiera configuran appenders TLS. |
| CVE-2021-* en `api` | Ausentes en `api` | Solo `log4j-core` (Apache lo explicita para 44228/45046) | **Atribución correcta** (DC no los propagó a `api`). Refuerza que el motor sí discrimina a veces. |

### 6.3 Qué no afirmar

- No afirmar “falso positivo confirmado” en 34479/34477/49844: la coincidencia de versión es real y el defecto existe en la línea 2.x; lo cuestionable es el **módulo**. La categoría correcta es **asociación potencialmente excesiva pendiente de confirmación**.
- No afirmar explotabilidad en la “aplicación”: los POM son mínimos sin código, configuración de appenders/layouts ni inputs. Todos los CVE 2021 (salvo 44228 base) y todos los 2025/2026 son **condicionales** (§4–§5).
- No usar el exit code Maven como prueba de limpieza: ambos POM fijan `failBuildOnCVSS=11`, por lo que el build **nunca falla por hallazgos** por diseño.

---

## 7. Comparación cuantitativa entre 2.14.1 y 2.17.1

Todos los cálculos derivan directamente de §3 (sin porcentajes inventados; las fracciones se muestran como conteos).

| Métrica comprobada | 2.14.1 | 2.17.1 | Diferencia |
|---|---|---|---|
| Dependencias escaneadas | 2 | 2 | 0 |
| Dependencias vulnerables | 2 | 2 | 0 |
| Asociaciones (HTML `Found` = suma JSON) | 12 (3 api + 9 core) | 8 (3 api + 5 core) | **−4** |
| CVE únicos | 9 | 5 | **−4** |
| CVE únicos CRITICAL (CVSSv3) | 2 | 0 | **−2** |
| En CISA KEV | 2 | 0 | **−2** |
| CVE que desaparecen | — | — | 4: CVE-2021-44228, CVE-2021-45046, CVE-2021-44832, CVE-2021-45105 |
| CVE que permanecen | — | — | 5: CVE-2025-68161, CVE-2026-34477, CVE-2026-34479, CVE-2026-34480, CVE-2026-49844 |
| CVE solo en 2.17.1 | — | — | 0 |
| Suprimidos | 0 | 0 | 0 |

**Lectura técnica:**

- El paso 2.14.1 → 2.17.1 elimina exactamente el clúster Log4Shell 2021, incluidos los 2 KEV y los 2 CRITICAL. Es la evidencia del “corregida frente a Log4Shell”.
- No deja el proyecto limpio con NVD a 2026-10-09: persisten 5 CVE posteriores (1 de 2025 + 4 de 2026) cuyos rangos incluyen 2.17.1. Presentar 2.17.1 como “0 vulnerabilidades” sería falso con estos datos.
- `log4j-api` es invariante (mismos 3 CVE); todo el delta está en `log4j-core` (9→5).
- El peso de los reportes cae en línea con el delta (HTML 529→201 KB, JSON 267→85 KB), por la desaparición de CVE-2021-44228 (351 `vulnerableSoftware`, 103 referencias) y afines.

---

## 8. Limitaciones y datos pendientes de confirmación

1. **Sin validación de alcanzabilidad.** Los POM no contienen aplicación, configuración ni tests. No se puede saber si se usan JDBC/Socket/SMTP/Syslog appenders, `XmlLayout`/`Log4j1XmlLayout`/`JsonTemplateLayout`, `MapMessage` o MDC controlable. Toda aplicabilidad condicional queda **indeterminada** en contexto.
2. **FP no confirmados.** Faltan `mvn dependency:tree`, inspección de clases (`Log4j1XmlLayout`, `XmlLayout`, `MapMessage`), configuración real y/o suppression documentada para elevar “excesiva probable” a “FP confirmado”.
3. **Ventana temporal NVD.** Los conteos dependen de NVD a 2026-10-09 (informes) y validación a 2026-10-10. Con otra fecha los CVE 2025/2026 podrían no existir o haber más. No extrapolar.
4. **CVSS dual.** Se citan CVSSv3.1 (escáner) y CVSS4.0 (Apache) cuando existen; no son intercambiables. La discrepancia `severity` vs `baseSeverity` (§2.4) sigue abierta.
5. **Discrepancia menor 44832** (`2.17.0` vs `2.17.1` como fix) sin impacto en el veredicto, pendiente de alinear con el VDR CycloneDX de Apache si se requiere precisión de parche.
6. **Cobertura de fuentes.** NVD bloquea scraping directo (solo home sin JS); se usaron resultados de búsqueda NVD + Apache + GHSA + CVE.org + OSV. Si el tribunal exige captura NVD literal, repetir la consulta manualmente.
7. **Representatividad.** Son dependencias mínimas, no una aplicación completa. Un `BUILD SUCCESS` con `failBuildOnCVSS=11` no significa ausencia de riesgo.
8. **Trazabilidad Git.** `target/` está ignorado por `.gitignore`; si los reportes deben versionarse como evidencia, hay que moverlos a `docs/`/`evidencias/` o forzar `git add -f`, o archivar hashes. Las rutas locales con nombre de usuario deberían redactarse al publicar.

---

## 9. Conclusiones técnicas

1. **Los 6 indicadores preliminares son correctos** tras contraste HTML/JSON (§1.3).
2. **Los 9 CVE de 2.14.1 existen en NVD y Apache** con los ID, rangos y CVSS reportados (módulo aparte). Los 4 CVE 2021 desaparecen correctamente en 2.17.1; los 5 restantes persisten correctamente por rango en 2.17.1.
3. **2.17.1 corrige Log4Shell pero no queda limpia:** mantiene 5 CVE 2025/2026 (todos MEDIUM en `severity`, dos con CVSSv3.1 HIGH 7.5). Cualquier afirmación de “versión segura” debe acotarse a “frente a Log4Shell/KEV 2021”.
4. **Tres asociaciones son excesivas probables por CPE genérico:** CVE-2026-34479 en `api`+`core` (oficial solo `1.2-api`), CVE-2026-34477 en `api` (oficial solo Core), CVE-2026-49844 en `core` (oficial solo `api`). CVE-2026-34480, sospechoso preliminar en `api`, resulta correctamente asignado solo a Core: la sospecha queda refutada.
5. **Ningún CVE puede declararse explotable en estos proyectos** (sin app/config/inputs) ni ningún FP declararse confirmado (sin árbol de dependencias ni inspección de clases). El lenguaje correcto para el informe académico es: *resultado del escáner / coincidencia CPE* vs *aplicabilidad condicional pendiente*.
6. **Evidencia suficiente para el apartado 3:** §3–§4 aportan tablas y conteos; §5 aporta las 9 fichas con condiciones; §6 aporta la discusión de validez; §2.4 y §8 aportan amenazas a la validez (CPE, fechas, `target/` ignorado).

---

## 10. Fuentes consultadas, con URL y fecha de consulta

Todas consultadas el **2026-10-10**. Se citan como referencia documental, no como reproducción.

**Evidencias locales (sin URL, ruta relativa):**

- `analisis-log4j/afectada/pom.xml`, `analisis-log4j/corregida/pom.xml`.
- `analisis-log4j/afectada/target/dependency-check-report.html` / `.json`.
- `analisis-log4j/corregida/target/dependency-check-report.html` / `.json`.

**Fuentes oficiales primarias:**

- Apache Logging Services — Security (agrupa CVE-2021-44228, 45046, 44832, 45105, 2025-68161, 2026-34477/34478/34479/34480/34481/49844, con componente, rangos VERS, CVSS 3.x/4.x y remedio): `https://logging.apache.org/log4j/2.x/security.html`
- Apache Logging Services — Security (raíz): `https://logging.apache.org/security.html`
- NVD CVE-2021-44228: `https://nvd.nist.gov/vuln/detail/CVE-2021-44228`
- NVD CVE-2021-45046: `https://nvd.nist.gov/vuln/detail/CVE-2021-45046`
- NVD CVE-2021-44832: `https://nvd.nist.gov/vuln/detail/CVE-2021-44832`
- NVD CVE-2021-45105: `https://nvd.nist.gov/vuln/detail/CVE-2021-45105`
- NVD CVE-2025-68161: `https://nvd.nist.gov/vuln/detail/CVE-2025-68161`
- NVD CVE-2026-34479: `https://nvd.nist.gov/vuln/detail/CVE-2026-34479`
- NVD CVE-2026-34477: `https://nvd.nist.gov/vuln/detail/CVE-2026-34477`
- NVD CVE-2026-34480: `https://nvd.nist.gov/vuln/detail/CVE-2026-34480`
- NVD CVE-2026-49844: `https://nvd.nist.gov/vuln/detail/CVE-2026-49844`
- CVE.org CVE-2021-44228: `https://www.cve.org/CVERecord?id=CVE-2021-44228`
- CVE.org CVE-2025-68161: `https://www.cve.org/CVERecord?id=CVE-2025-68161`

**Mapeo Maven / confirmación de artefacto:**

- GHSA CVE-2026-34479 (`org.apache.logging.log4j:log4j-1.2-api`): `https://github.com/advisories/GHSA-h383-gmxw-35v2`
- GHSA CVE-2026-34480 (`org.apache.logging.log4j:log4j-core`): `https://github.com/advisories/GHSA-3pxv-7cmr-fjr4`
- GHSA CVE-2026-49844 (contexto `log4j-api`): `https://github.com/advisories/ghsa-qv9r-c865-cp47`
- GHSA CVE-2025-68161 (`org.apache.logging.log4j:log4j-core`): `https://github.com/advisories/GHSA-vc5p-v9hr-52mj`
- OSV CVE-2026-34480 / CVE-2026-49844 (rangos CPE y versiones): `https://osv.dev/vulnerability/CVE-2026-34480`, `https://osv.dev/vulnerability/CVE-2026-49844`

**CISA:**

- KEV Catalog: `https://www.cisa.gov/known-exploited-vulnerabilities-catalog` (verifica CVE-2021-44228 y CVE-2021-45046; ausencia de los otros 7).
- AA21-356A Log4Shell guidance: `https://www.cisa.gov/news-events/cybersecurity-advisories/aa21-356a`
- CISA Log4j guidance: `https://www.cisa.gov/news-events/news/apache-log4j-vulnerability-guidance`

**Referencias secundarias citadas solo como corroboración (no como fuente de veredicto):**

- IBM Security Bulletin (describe CVE-2026-34477/34479/34480 con vectores NVD): `https://www.ibm.com/support/pages/security-bulletin-apache-log4j-2-package-shipped-ibm-applinx-vulnerable-multiple-vulnerabilities-cve-2026-34480-cve-2026-34477-cve-2026-34478-cve-2026-34479`
- SentinelOne CVE-2026-49844: `https://www.sentinelone.com/vulnerability-database/cve-2026-49844/`
