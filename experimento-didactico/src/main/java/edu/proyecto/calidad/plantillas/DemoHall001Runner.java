package edu.proyecto.calidad.plantillas;

import java.util.HashMap;
import java.util.Map;

/**
 * Runner de demostración académica del caso conocido HALL-001.
 *
 * <p>Invoca el código real de ambas variantes sin simular resultados:
 * {@link ResolutorPlantillas#resolver(String, Map)} (V-A) y
 * {@link ResolutorPlantillasCorregido#resolver(String, Map)} (V-B).</p>
 *
 * <p>Ejecutable directamente desde el IDE (Run) para captura de evidencia.</p>
 */
public class DemoHall001Runner {

    private static final String PLANTILLA = "Hola, ${mayusculas:nombre}";
    private static final String CLAVE = "nombre";
    private static final String DATO = "ana ${minusculas:XYZ}";

    public static void main(String[] args) {
        Map<String, String> contexto = new HashMap<>();
        contexto.put(CLAVE, DATO);

        System.out.println("=== Demostración HALL-001 ===");
        System.out.println("Entrada:");
        System.out.println("  Plantilla : " + PLANTILLA);
        System.out.println("  Dato      : " + DATO);
        System.out.println();

        System.out.println("--- Ejecución de V-A (ResolutorPlantillas) ---");
        String resultadoVA = new ResolutorPlantillas().resolver(PLANTILLA, contexto);
        System.out.println("Resultado V-A: " + resultadoVA);
        System.out.println();

        System.out.println("--- Ejecución de V-B (ResolutorPlantillasCorregido) ---");
        String resultadoVB = new ResolutorPlantillasCorregido().resolver(PLANTILLA, contexto);
        System.out.println("Resultado V-B: " + resultadoVB);
        System.out.println();

        System.out.println("--- Diferencia observada ---");
        if (resultadoVA.equals(resultadoVB)) {
            System.out.println("Sin diferencia: ambas variantes devuelven el mismo resultado.");
        } else {
            System.out.println("DIFERENCIA OBSERVADA:");
            System.out.println("  V-A reinterpreta la expresión del dato no confiable.");
            System.out.println("  V-B la preserva como texto literal (no la reinterpreta).");
        }
    }
}
