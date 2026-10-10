package edu.proyecto.calidad.plantillas;

import static org.junit.jupiter.api.Assertions.fail;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Oráculo compartido de la propiedad de no reinterpretación (F-04/F-06).
 *
 * <p>Calcula el resultado de referencia sustituyendo el dato de forma opaca
 * en una sola pasada, sin reexpansión: las secuencias {@code ${...}} del
 * dato se enmascaran antes de aplicar la función y se restauran después.
 * No reutiliza el bucle de reexpansión de V-A. Ambas variantes se juzgan
 * con la misma regla.</p>
 *
 * <p>Límites documentados: solo soporta plantillas con una única expresión
 * {@code ${funcion:clave}} (otra forma aborta como error del arnés, no como
 * hallazgo); el enmascarado usa cierre balanceado; los marcadores de
 * apertura y cierre son distintos (corrección FP-ORACULO-002: con un único
 * marcador, el cierre de un triple más un dígito literal más la apertura
 * del siguiente podían formar un triple fantasma consumido antes de
 * tiempo); un dato nulo no se acepta aquí (el arnés lo normaliza a
 * {@code ""} de forma explícita).</p>
 */
final class OraculoNoReinterpretacion {

    private OraculoNoReinterpretacion() {
    }

    static String referenciaUnaPasada(String plantilla, String clave, String dato) {
        int inicio = plantilla.indexOf("${");
        int fin = inicio < 0 ? -1 : plantilla.indexOf('}', inicio + 2);
        if (inicio < 0 || fin < 0) {
            fail("Plantilla fuera de la forma soportada por el oráculo: " + plantilla);
        }
        String interior = plantilla.substring(inicio + 2, fin);
        int separador = interior.indexOf(':');
        String funcion = separador < 0 ? interior : interior.substring(0, separador);
        String referenciaClave = separador < 0 ? interior : interior.substring(separador + 1);
        if (!referenciaClave.equals(clave)) {
            fail("Clave inesperada en la plantilla: " + referenciaClave);
        }
        String sustituto;
        switch (funcion) {
            case "mayusculas":
                sustituto = aplicarConMascara(dato, true);
                break;
            case "minusculas":
                sustituto = aplicarConMascara(dato, false);
                break;
            case "longitud":
                sustituto = String.valueOf(dato.length());
                break;
            default:
                sustituto = "${" + interior + "}";
                break;
        }
        return plantilla.substring(0, inicio) + sustituto + plantilla.substring(fin + 1);
    }

    private static String aplicarConMascara(String dato, boolean aMayusculas) {
        char[] marcas = buscarMarcadoresLibres(dato);
        char apertura = marcas[0];
        char cierre = marcas[1];
        List<String> expresiones = new ArrayList<>();
        StringBuilder enmascarado = new StringBuilder();
        int indice = 0;
        while (indice < dato.length()) {
            int inicio = dato.indexOf("${", indice);
            if (inicio < 0) {
                enmascarado.append(dato, indice, dato.length());
                break;
            }
            enmascarado.append(dato, indice, inicio);
            // Cierre balanceado (corrección FP-ORACULO-001): el primer '}'
            // no basta con expresiones anidadas o incompletas.
            int fin = buscarCierre(dato, inicio + 2);
            if (fin < 0) {
                enmascarado.append(dato, inicio, dato.length());
                break;
            }
            expresiones.add(dato.substring(inicio, fin + 1));
            enmascarado.append(apertura).append(expresiones.size() - 1).append(cierre);
            indice = fin + 1;
        }
        String transformado = aMayusculas
                ? enmascarado.toString().toUpperCase(Locale.ROOT)
                : enmascarado.toString().toLowerCase(Locale.ROOT);
        String restaurado = transformado;
        for (int i = 0; i < expresiones.size(); i++) {
            restaurado = restaurado.replace(
                    String.valueOf(apertura) + i + cierre, expresiones.get(i));
        }
        return restaurado;
    }

    /**
     * Localiza el cierre balanceado de una expresión (misma regla
     * sintáctica que las variantes; sin reexpansión asociada).
     */
    private static int buscarCierre(String texto, int desde) {
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
    /**
     * Reserva dos marcadores distintos y ausentes del dato, uno de apertura
     * y otro de cierre, para que ninguna concatenación de restos con texto
     * literal pueda formar un triple fantasma.
     */
    private static char[] buscarMarcadoresLibres(String dato) {
        char[] libres = new char[2];
        int encontrados = 0;
        for (char candidato = '\uE000'; candidato <= '\uE00A' && encontrados < 2; candidato++) {
            if (dato.indexOf(candidato) < 0) {
                libres[encontrados] = candidato;
                encontrados++;
            }
        }
        if (encontrados < 2) {
            fail("El dato contiene todos los marcadores candidatos; oráculo no aplicable.");
        }
        return libres;
    }
}
