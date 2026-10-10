package edu.proyecto.calidad.plantillas;

import java.util.Collections;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

/**
 * Variante V-A (defectuosa) del resolvedor de plantillas de registro.
 *
 * <p>Modelo didáctico: expande expresiones {@code ${nombre}} y
 * {@code ${nombre:argumento}} con funciones locales e inocuas
 * ({@code minusculas}, {@code mayusculas}, {@code longitud}).
 * Todo ocurre en memoria; sin red, sin JNDI/LDAP/RMI, sin carga
 * dinámica de clases y sin ejecución de código.</p>
 *
 * <p>Condición de riesgo modelada: tras resolver la plantilla autorizada,
 * el resultado completo vuelve a pasar por el intérprete, de modo que las
 * expresiones aportadas por el dato no confiable (valores del contexto) se
 * evalúan indebidamente.</p>
 */
public class ResolutorPlantillas {

    /** Guarda anti-bucle: número máximo de pasadas de reexpansión. */
    static final int MAXIMO_PASADAS = 100;

    /** Guarda anti-bucle: profundidad máxima de expresiones anidadas. */
    static final int MAXIMA_PROFUNDIDAD = 50;

    /**
     * Resuelve la plantilla autorizada con el contexto dado.
     *
     * <p>En V-A el resultado se reexpande hasta alcanzar un punto fijo:
     * las expresiones introducidas por los valores del contexto (dato no
     * confiable) también se evalúan.</p>
     *
     * @param plantillaAutorizada plantilla controlada por el desarrollador, no nula
     * @param contexto valores disponibles; un contexto nulo se trata como vacío
     * @return cadena resuelta
     */
    public String resolver(String plantillaAutorizada, Map<String, String> contexto) {
        Objects.requireNonNull(plantillaAutorizada, "La plantilla autorizada no puede ser nula");
        Map<String, String> valores = contexto != null ? contexto : Collections.emptyMap();
        String actual = plantillaAutorizada;
        for (int pasada = 0; pasada < MAXIMO_PASADAS; pasada++) {
            String siguiente = expandirUnaPasada(actual, valores, 0);
            if (siguiente.equals(actual)) {
                return actual;
            }
            actual = siguiente;
        }
        return actual;
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
            // (en V-A podrá reexpandirse en pasadas posteriores).
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
     * preservando intactas las secuencias {@code ${...}} embebidas.
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
