# Experimento didáctico: reinterpretación de expresiones en plantillas

Experimento reproducible de calidad de software que compara dos variantes de un resolvedor de plantillas de registro: una variante con una condición de riesgo deliberada (V-A) y una variante corregida (V-B). Está dirigido a estudiantes, desarrolladores, investigadores y cualquier persona interesada en pruebas automatizadas, fuzzing, oráculos independientes y análisis estático.

El proyecto se contextualiza académicamente en el estudio de defectos inspirados en el caso Log4Shell (CVE-2021-44228), pero **no implementa ni reproduce la vulnerabilidad real ni ninguna explotación**.

## 1. Propósito del experimento

Cuando un programa combina una plantilla controlada por el desarrollador con datos no confiables (por ejemplo, un nombre de usuario que llega por una petición), existe un riesgo clásico: que el intérprete de plantillas vuelva a interpretar como instrucciones el contenido aportado por el dato.

Este experimento modela ese riesgo de forma mínima y segura, y permite responder con evidencia ejecutable:

* ¿Detectan las pruebas automatizadas la reinterpretación no deseada?
* ¿Qué aporta el fuzzing con generación de entradas frente a la regresión determinista?
* ¿Qué puede y qué no puede aportar el análisis estático?
* ¿Cómo se juzga el comportamiento con un oráculo independiente del código bajo prueba?

Todo el código es Java estándar, sin red, sin JNDI, sin LDAP, sin RMI, sin carga dinámica de clases y sin ejecución de código. Las únicas “funciones de plantilla” son operaciones locales e inocuas sobre cadenas: `minusculas`, `mayusculas` y `longitud`.

## 2. Alcance y advertencia de uso exclusivamente didáctico

* **V-A es deliberadamente vulnerable.** Contiene un bucle de reexpansión que evalúa expresiones aportadas por el dato. No debe reutilizarse como patrón de diseño ni trasladarse a una aplicación real.
* **V-B es una corrección didáctica, no un componente de producción.** Ilustra dos defensas concretas (una sola pasada de expansión y límites de longitud con rechazo explícito), pero no constituye una librería de plantillas endurecida.
* **Analogía con Log4Shell, no reproducción.** El experimento comparte con Log4Shell únicamente la idea abstracta —“el dato no confiable no debe reinterpretarse como instrucción”—, con funciones inocuas y sin ningún servicio remoto. No hay explotación de JNDI, LDAP ni servicios externos, ni se reproduce CVE alguno.
* **Técnicas consideradas:** pruebas JUnit 5, fuzzing con Jazzer (JUnit integration), oráculo independiente de referencia y análisis estático con SpotBugs + FindSecBugs. Ninguna técnica, por sí sola, “demuestra” seguridad; cada una aporta un tipo distinto de evidencia, con las limitaciones descritas en la sección 9.

## 3. Descripción de V-A y V-B

Ambas variantes comparten sintaxis y funciones autorizadas:

* `${nombre}`: referencia simple a una variable del contexto (el dato no confiable viaja como valor asociado a la variable).
* `${funcion:argumento}`: `minusculas`, `mayusculas` (aplicadas a los segmentos literales, preservando byte a byte las secuencias `${...}` embebidas) y `longitud` (longitud del argumento). Funciones desconocidas o expresiones sin cerrar se conservan como texto literal.
* El argumento se resuelve primero contra el contexto; si la clave no existe, se usa el texto tal cual como literal.
* El anidamiento escrito en la plantilla autorizada (por ejemplo, `${mayusculas:${minusculas:ABC}}`) se resuelve con una guarda de profundidad máxima de 50.

La diferencia está en qué ocurre **después** de resolver la plantilla autorizada:

| Aspecto | V-A (`ResolutorPlantillas`) | V-B (`ResolutorPlantillasCorregido`) |
|---|---|---|
| Expansión | El resultado completo vuelve a pasar por el intérprete hasta alcanzar un punto fijo (máximo 100 pasadas) | Una sola pasada; los valores del contexto nunca vuelven a pasar por el intérprete |
| Valores del contexto | Pueden reexpandirse en pasadas posteriores (condición de riesgo modelada) | Se tratan como texto literal; las secuencias `${...}` que contienen quedan inertes en la salida, conservadas byte a byte para auditoría |
| Límites de longitud | Sin límites (solo guardas anti-bucle) | Plantilla hasta 100 000 caracteres; cada valor hasta 10 000; todo exceso se rechaza con `IllegalArgumentException`, sin truncamiento silencioso |
| Contratos nulos | Plantilla nula: `NullPointerException`; contexto nulo: se trata como vacío | Idéntico contrato |

V-A y V-B son clases independientes; V-A se conserva intacta para poder comparar comportamientos.

## 4. Ejemplo: el dato `ana ${minusculas:XYZ}`

Plantilla autorizada (controlada por el desarrollador):

```text
Hola, ${mayusculas:nombre}
```

Dato no confiable (valor de la variable `nombre` en el contexto):

```text
ana ${minusculas:XYZ}
```

Comportamiento especificado por las pruebas (no es una afirmación de una ejecución recién realizada en esta revisión; ver sección 9):

* **V-A** produce `Hola, ANA xyz` (TEST-006 en `ResolutorPlantillasTest.java`). Primera pasada: la función `mayusculas` convierte el segmento literal `ana ` en `ANA ` y preserva `${minusculas:XYZ}`; segunda pasada: esa expresión preservada se evalúa indebidamente a `xyz`. La expresión del dato ha sido reinterpretada como instrucción.
* **V-B** produce `Hola, ANA ${minusculas:XYZ}` (TEST-VB-04 en `ResolutorPlantillasCorregidoTest.java`). La misma función convierte `ana ` en `ANA `, pero la secuencia `${minusculas:XYZ}` procedente del valor queda como texto literal e inerte, al no existir reexpansión.

La clase `DemoHall001Runner.java` ejecuta el código real de ambas variantes con este ejemplo canónico y muestra la diferencia por consola. Puede ejecutarse desde el IDE (Run `DemoHall001Runner`, según su Javadoc); el `pom.xml` no configura ningún plugin específico para ejecutarla mediante Maven, por lo que no se documenta aquí un comando Maven para ella. Es útil para una primera toma de contacto antes de ejecutar las pruebas.

## 5. Estructura de los archivos publicados

La publicación mínima contiene exclusivamente estos archivos:

```text
README.md
.gitignore
experimento-didactico/
├── pom.xml
└── src/
    ├── main/java/edu/proyecto/calidad/plantillas/
    │   ├── ResolutorPlantillas.java          # V-A (defectuosa)
    │   ├── ResolutorPlantillasCorregido.java # V-B (corregida)
    │   └── DemoHall001Runner.java            # Demostración del caso del apartado 4
    └── test/java/edu/proyecto/calidad/plantillas/
        ├── ResolutorPlantillasTest.java            # 12 pruebas JUnit de V-A
        ├── ResolutorPlantillasCorregidoTest.java   # 19 pruebas JUnit de V-B
        ├── ResolutorPlantillasFuzzTest.java        # Objetivo Jazzer de V-A
        ├── ResolutorPlantillasCorregidoFuzzTest.java # Objetivo Jazzer de V-B
        └── OraculoNoReinterpretacion.java    # Oráculo independiente compartido
```

No forman parte de la publicación los diarios de trabajo, registros de consola, evidencias archivadas ni mini-proyectos de análisis de dependencias reales que existen en el disco local de desarrollo (`docs/`, `registros/`, `evidencias/`, `analisis-log4j/`). Permanecen localmente y no deben versionarse.

## 6. Requisitos de Java y Maven

* **JDK 21 recomendado** para ejecutar el proyecto (el código se compila con nivel de bytecode `release 11`, por lo que un JDK 11 o posterior puede compilarlo; en ejecuciones anteriores documentadas localmente, no incluidas en esta publicación, los objetivos Jazzer se ejecutaron con JDK 21; la repetición de esas ejecuciones en un entorno limpio queda pendiente, ver sección 9).
* **Apache Maven 3.9.x.**
* Dependencias y plugins fijados en `experimento-didactico/pom.xml` (ámbito de prueba salvo indicación): JUnit Jupiter (`api`, `engine`, `params`) 5.10.5, `jazzer-junit` 0.30.0, `maven-compiler-plugin` 3.16.0, `maven-surefire-plugin` 3.6.0, `spotbugs-maven-plugin` 4.8.3.1 con `findsecbugs-plugin` 1.14.0. El código principal no tiene dependencias de ejecución: solo Java estándar.
* No se requieren variables de entorno especiales salvo las de Jazzer descritas en la sección 8. No se requieren claves, credenciales ni acceso a servicios externos para compilar y probar el experimento didáctico.

## 7. Instrucciones para compilar y ejecutar las pruebas

Todos los comandos Maven se ejecutan desde el directorio `experimento-didactico/`. Ejemplos en Windows PowerShell; al final se indica la variante portable.

### 7.1. Compilar

```powershell
Set-Location experimento-didactico
mvn --batch-mode compile
```

### 7.2. Verificar la implementación corregida (V-B)

Batería JUnit de 19 pruebas: funciones legítimas, preservación literal del dato con expresiones, bordes (`a ${b`, `a } b`, vacíos), anidamiento en plantilla autorizada, límites de longitud exactos y con exceso en uno, y contratos nulos.

```powershell
mvn --batch-mode "-Dtest=ResolutorPlantillasCorregidoTest" test
```

El resultado esperado según lo especificado por las pruebas es que las 19 pasen. La verificación de compilación y ejecución en este entorno queda pendiente de una etapa controlada posterior; no se afirma aquí ninguna ejecución recién realizada.

### 7.3. Caracterizar el comportamiento de V-A

Batería JUnit de 12 pruebas. Documenta como comportamiento observado de V-A la reinterpretación del dato (por ejemplo, `TEST-006` especifica `Hola, ANA xyz` para el caso del apartado 4). Ninguna prueba está escrita para fallar: cada una fija el resultado que V-A realmente produce.

```powershell
mvn --batch-mode "-Dtest=ResolutorPlantillasTest" test
```

### 7.4. Fuzzing de V-A (el fallo es un resultado esperado)

El objetivo `ResolutorPlantillasFuzzTest.datoNoSeReinterpreta` evalúa la propiedad “las expresiones del dato no confiable deben permanecer como texto literal” con cinco semillas (`ana`, `ana ${minusculas:XYZ}`, `ana ${girar:xy}`, `a ${b`, `a } b`) y la compara con el oráculo independiente. En V-A, la semilla `ana ${minusculas:XYZ}` **incumple deliberadamente la propiedad**: el fallo de aserción correspondiente es el hallazgo didáctico central, no un problema de infraestructura.

Regresión determinista (solo semillas, sin generar entradas nuevas). Requiere los argumentos de JVM de Jazzer (ver sección 8):

```powershell
mvn --batch-mode "-Dtest=ResolutorPlantillasFuzzTest" "-DargLine=-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading" test
```

Resultado esperado según lo especificado: error de aserción en la semilla de referencia (`expected: <Hola, ANA ${minusculas:XYZ}> but was: <Hola, ANA xyz>`), resto de semillas sin violación de la propiedad. **No debe presentarse este fallo como si el proyecto completo estuviera libre de errores**: es la evidencia de que V-A reinterpreta el dato.

### 7.5. Fuzzing de V-B

El objetivo `ResolutorPlantillasCorregidoFuzzTest.datoNoSeReinterpretaEnCorregido` evalúa la misma propiedad con el mismo oráculo y las mismas cinco semillas, más una semilla larga de 10 001 caracteres que ejercita la ruta de rechazo por longitud. Las semillas válidas deben respetar la propiedad; la entrada que supera el límite debe rechazarse con `IllegalArgumentException` (el oráculo no modela esa ruta; la prueba exige el rechazo explícito en su lugar).

```powershell
# Regresión determinista
mvn --batch-mode "-Dtest=ResolutorPlantillasCorregidoFuzzTest" "-DargLine=-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading" test
```

```powershell
# Fuzzing con generación de entradas (90 segundos)
$env:JAZZER_FUZZ = "1"
$env:JAZZER_MAX_DURATION = "90s"
mvn --batch-mode "-Dtest=ResolutorPlantillasCorregidoFuzzTest" "-DargLine=-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading" test
Remove-Item Env:\JAZZER_FUZZ
Remove-Item Env:\JAZZER_MAX_DURATION
```

El mismo patrón de variables sirve para V-A si se desea observar la generación de entradas alrededor del hallazgo conocido.

### 7.6. Variante portable (Linux / macOS)

```bash
cd experimento-didactico
mvn --batch-mode "-Dtest=ResolutorPlantillasCorregidoTest" test
JAZZER_FUZZ=1 JAZZER_MAX_DURATION=90s mvn --batch-mode "-Dtest=ResolutorPlantillasCorregidoFuzzTest" "-DargLine=-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading" test
```

### 7.7. Análisis estático con SpotBugs y FindSecBugs

La configuración del plugin está declarada en `experimento-didactico/pom.xml` (`spotbugs-maven-plugin` 4.8.3.1 con `findsecbugs-plugin` 1.14.0 anidado), por lo que el siguiente comando es compatible con el proyecto sin cambios adicionales. No se ha ejecutado en esta intervención:

```powershell
mvn --batch-mode compile spotbugs:check
```

Como referencia histórica (no como comprobación recién realizada): informes anteriores del proyecto, respaldados por evidencias locales no incluidas en esta publicación mínima, registraron cero hallazgos tanto en V-A como en V-B con esta configuración. Ese cero histórico no debe interpretarse como prueba de ausencia de defectos —de hecho, V-A contiene la reinterpretación documentada— sino como evidencia de las limitaciones del análisis estático genérico frente a esta clase de defecto lógico.

## 8. Regresión determinista frente a fuzzing con generación

* **Regresión determinista (sin `JAZZER_FUZZ`):** Jazzer en modo JUnit ejecuta cada semilla exactamente una vez, como un caso parametrizado más. Es rápida, repetible y adecuada para verificar el contrato fijado. Los comandos deterministas no requieren activar `JAZZER_FUZZ`, pero los comandos de los objetivos Jazzer (apartados 7.4–7.5) siguen necesitando los argumentos `-DargLine=...` documentados para configurar la JVM.
* **Fuzzing con generación (`JAZZER_FUZZ=1`):** el mismo objetivo reutiliza las semillas y genera/muta entradas durante `JAZZER_MAX_DURATION` (vacía significa sin límite; `90s` es una duración acotada razonable para este experimento). Las entradas generadas se almacenan en `.cifuzz-corpus/` (excluido del control de versiones) y los fallos producen ficheros `crash-*` (también excluidos). Sirve para buscar contraejemplos adicionales más allá de las semillas; que no aparezcan en una corrida acotada no demuestra ausencia de defectos.

Condiciones necesarias para Jazzer (verificadas por inspección de la configuración y de la documentación de la herramienta, no por ejecución en esta etapa):

* Los argumentos de JVM `-Djdk.attach.allowAttachSelf=true -XX:+EnableDynamicAgentLoading` deben pasarse vía `-DargLine=...`, porque el `pom.xml` no los fija y el agente de Jazzer necesita autoacoplarse en JDK 21. Sin ellos, la ejecución aborta con un error de infraestructura (`ByteBuddyAgent`: no puede autoacoplarse), que no debe confundirse con un hallazgo.
* La anotación `@FuzzTest` debe ser la última en el método objetivo (así está en el código actual).
* La semilla de cadena vacía no se incluye como `@MethodSource` porque la versión fijada de `junit-jupiter-params` (5.10.5) aborta el contenedor ante nombres de invocación en blanco; el caso vacío se cubre en las pruebas unitarias y en la mutación del fuzzer. El dato nulo se normaliza explícitamente a cadena vacía en el arnés.

## 9. Resultados esperados y limitaciones

Distinción importante entre tres niveles:

1. **Comportamiento especificado por las pruebas** (verificable por lectura del código, sin necesidad de ejecutar): V-A reinterpreta (`TEST-006`, `TEST-010`); V-B preserva (`TEST-VB-04`, `TEST-VB-09`, `TEST-VB-10`, `TEST-VB-15`); los límites se rechazan con `IllegalArgumentException` (`TEST-VB-17`, `TEST-VB-19`); el fuzz de V-A especifica la violación de la propiedad en la semilla de referencia.
2. **Resultados de ejecuciones anteriores respaldados por evidencias locales** (no incluidos en esta publicación mínima y no reafirmados aquí como ejecuciones nuevas): baterías unitarias en verde, hallazgo de la semilla de referencia en el fuzz de V-A con el mensaje citado en 7.4, ausencia de violaciones en corridas acotadas del fuzz de V-B, y cero hallazgos del análisis estático en ambas variantes.
3. **Verificaciones pendientes:** la compilación y ejecución controladas en un entorno limpio (incluida la comprobación de los comandos de este README con JDK 21 y Maven 3.9.x) se realizarán después de esta intervención documental y quedan expresamente pendientes.

Limitaciones del experimento que deben tenerse presentes:

* El oráculo solo modela plantillas con una única expresión `${funcion:clave}` y la localiza mediante el primer carácter `}`; su uso en fuzzing está restringido a la plantilla fija utilizada por esos objetivos. Fuera de esa forma aborta como error del arnés, no como hallazgo, y no cubre de manera general todas las formas de anidamiento que admiten los resolutores (por ejemplo, las plantillas anidadas de TEST-007 y TEST-VB-12). La función `longitud` no discrimina reinterpretación (devuelve un número en ambas variantes).
* La ausencia de contraejemplos en una corrida de fuzzing acotada no demuestra corrección universal.
* El cero del análisis estático no detectó ni reportó el defecto lógico de V-A; no debe usarse como argumento de seguridad.
* No se publican cifras globales de ejecuciones, duraciones, tamaños de corpus ni cobertura, al no ser verificables en esta etapa mínima.

## 10. Relación entre las pruebas automatizadas y el oráculo independiente

* Las pruebas **unitarias** fijan el contrato con valores concretos escritos a mano (qué debe devolver cada variante para cada entrada representativa, incluidos bordes y límites). Son legibles y estables, pero solo cubren los casos escritos.
* Las pruebas de **fuzzing** generalizan una única propiedad —no reinterpretación del dato— a cualquier entrada que el generador proponga, comparando la salida real contra el **oráculo independiente** (`OraculoNoReinterpretacion`).
* El oráculo calcula el resultado de referencia por un camino distinto al código bajo prueba: sustitución opaca del dato en una sola pasada, enmascarando sus secuencias `${...}` con marcadores ausentes del dato antes de aplicar la función y restaurándolas después, con cierre balanceado. No reutiliza el bucle de reexpansión de V-A, pero comparte con ambas implementaciones la regla de cierre balanceado de las expresiones; su independencia se refiere a la propiedad de no reinterpretación, no a la totalidad del análisis sintáctico. Ambas variantes se juzgan con la misma regla externa.
* El oráculo tuvo dos correcciones justificadas de su propio arnés (cierre balanceado en el enmascarado; dos marcadores distintos de apertura y cierre para evitar triples fantasma), sin modificar V-A ni ocultar su hallazgo. Estos detalles están documentados en el código del oráculo para quien desee auditarlo.
