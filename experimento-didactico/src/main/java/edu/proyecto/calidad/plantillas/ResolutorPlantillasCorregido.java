package edu.proyecto.calidad.plantillas;

import java.util.Collections;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

/**
 * Variante V-B (corregida) del resolvedor de plantillas de registro.
 *
 * <p>Difiere de V-A ({@link ResolutorPlantillas}) en dos puntos:
 * (1) la plantilla autorizada se expande en <strong>una sola
 * pasada</strong> y los valores del contexto (dato no confiable) nunca
 * vuelven a pasar por el intérprete; (2) se aplican <strong>límites de
 * longitud</strong> a la plantilla y a cada valor, con rechazo explícito.
 * Todo lo demás —sintaxis, funciones autorizadas
 * ({@code minusculas}, {@code mayusculas}, {@code longitud}), paso de
 * variables y literales— se comporta igual.</p>
 *
 * <p>Política de neutralización: las secuencias {@code ${} procedentes de
 * los valores se conservan byte a byte en la salida (preservadas durante la
 * aplicación de funciones) y, al no existir reexpansión, quedan inertes.
 * No se reescriben, para conservarlas auditables.</p>
 *
 * <p>Todo ocurre en memoria; sin red, sin JNDI/LDAP/RMI, sin carga
 * dinámica de clases y sin ejecución de código. No existe el bucle de
 * reexpansión de V-A, por lo que no se necesita su guarda de pasadas; se
 * mantiene la guarda de profundidad de anidamiento.</p>
 *
 * <p>Límites de longitud (F-06B): la plantilla, controlada por el
 * desarrollador, admite hasta {@value #LONGITUD_MAXIMA_PLANTILLA}
 * caracteres; cada valor no confiable del contexto, hasta
 * {@value #LONGITUD_MAXIMA_VALOR}. Todo exceso se rechaza con
 * {@link IllegalArgumentException}, sin truncamiento silencioso (truncar
 * corrompería registros y rompería la igualdad verificable).</p>
 */
public class ResolutorPlantillasCorregido {

    /** Guarda: profundidad máxima de expresiones anidadas. */
    static final int MAXIMA_PROFUNDIDAD = 50;

    /**
     * Longitud máxima de la plantilla autorizada (origen confiable; margen
     * amplio sobre plantillas realistas de pocos miles de caracteres).
     */
    static final int LONGITUD_MAXIMA_PLANTILLA = 100_000;

    /**
     * Longitud máxima de cada valor no confiable del contexto (margen sobre
     * campos de registro típicos de 1–2 KB; TEST-VB-13 usa 5000).
     */
    static final int LONGITUD_MAXIMA_VALOR = 10_000;

    /**
     * Resuelve la plantilla autorizada con el contexto dado, en una sola
     * pasada. Los valores del contexto se tratan como texto literal.
     *
     * @param plantillaAutorizada plantilla controlada por el desarrollador, no nula
     * @param contexto valores disponibles; un contexto nulo se trata como vacío
     * @return cadena resuelta, sin reinterpretación posterior
     */
    public String resolver(String plantillaAutorizada, Map<String, String> contexto) {
        Objects.requireNonNull(plantillaAutorizada, "La plantilla autorizada no puede ser nula");
        if (plantillaAutorizada.length() > LONGITUD_MAXIMA_PLANTILLA) {
            throw new IllegalArgumentException(
                    "La plantilla supera la longitud máxima de " + LONGITUD_MAXIMA_PLANTILLA
                            + " caracteres (recibidos " + plantillaAutorizada.length() + ")");
        }
        Map<String, String> valores = contexto != null ? contexto : Collections.emptyMap();
        for (Map.Entry<String, String> entrada : valores.entrySet()) {
            if (entrada.getValue() != null && entrada.getValue().length() > LONGITUD_MAXIMA_VALOR) {
                throw new IllegalArgumentException(
                        "El valor de '" + entrada.getKey() + "' supera la longitud máxima de "
                                + LONGITUD_MAXIMA_VALOR + " caracteres (recibidos "
                                + entrada.getValue().length() + ")");
            }
        }
        return expandirUnaPasada(plantillaAutorizada, valores, 0);
    }

    private String expandirUnaPasada(String texto, Map<String, String> contexto, int profundidad) {
        if (profundidad > MAXIMA_PROFUNDIDAD) {
            return texto;
        }
        StringBuilder salida = new StringBuilder();
        int indice = 0;
        while (indice < texto.length()) {
            int inicio = texto.indexOf("${", indice);
            if (inicio < 0) {
                salida.append(texto, indice, texto.length());
                break;
            }
            salida.append(texto, indice, inicio);
            int fin = buscarCierre(texto, inicio + 2);
            if (fin < 0) {
                // Expresión sin cerrar: se conserva literal.
                salida.append(texto, inicio, texto.length());
                break;
            }
            String interior = texto.substring(inicio + 2, fin);
            String interiorExpandido = expandirUnaPasada(interior, contexto, profundidad + 1);
            salida.append(evaluarExpresion(interiorExpandido, contexto));
            indice = fin + 1;
        }
        return salida.toString();
    }

    private int buscarCierre(String texto, int desde) {
        int anidamiento = 0;
        for (int i = desde; i < texto.length(); i++) {
            char actual = texto.charAt(i);
            if (actual == '$' && i + 1 < texto.length() && texto.charAt(i + 1) == '{') {
                anidamiento++;
                i++;
            } else if (actual == '}') {
                if (anidamiento == 0) {
                    return i;
                }
                anidamiento--;
            }
        }
        return -1;
    }

    private String evaluarExpresion(String interior, Map<String, String> contexto) {
        int separador = interior.indexOf(':');
        if (separador < 0) {
            // Referencia simple a variable: el valor se inserta tal cual
            // y, al no haber más pasadas, queda como texto literal.
            String valor = contexto.get(interior);
            return valor != null ? valor : "${" + interior + "}";
        }
        String nombre = interior.substring(0, separador);
        String argumentoCrudo = interior.substring(separador + 1);
        // El argumento se resuelve primero contra el contexto; si la clave
        // no existe, se usa el texto tal cual como literal.
        String argumento = contexto.getOrDefault(argumentoCrudo, argumentoCrudo);
        switch (nombre) {
            case "minusculas":
                return transformarSegmentosLiterales(argumento, true);
            case "mayusculas":
                return transformarSegmentosLiterales(argumento, false);
            case "longitud":
                return String.valueOf(argumento.length());
            default:
                // Función desconocida: se conserva literal.
                return "${" + interior + "}";
        }
    }

    /**
     * Aplica minúsculas/mayúsculas solo a los segmentos literales,
     * preservando intactas las secuencias {@code ${...}} embebidas, que al
     * no reexpandirse quedan inertes en la salida.
     */
    private String transformarSegmentosLiterales(String argumento, boolean aMinusculas) {
        StringBuilder salida = new StringBuilder();
        int indice = 0;
        while (indice < argumento.length()) {
            int inicio = argumento.indexOf("${", indice);
            if (inicio < 0) {
                salida.append(convertir(argumento.substring(indice), aMinusculas));
                break;
            }
            salida.append(convertir(argumento.substring(indice, inicio), aMinusculas));
            int fin = buscarCierre(argumento, inicio + 2);
            if (fin < 0) {
                salida.append(convertir(argumento.substring(inicio), aMinusculas));
                break;
            }
            salida.append(argumento, inicio, fin + 1);
            indice = fin + 1;
        }
        return salida.toString();
    }

    private String convertir(String segmento, boolean aMinusculas) {
        return aMinusculas
                ? segmento.toLowerCase(Locale.ROOT)
                : segmento.toUpperCase(Locale.ROOT);
    }
}
