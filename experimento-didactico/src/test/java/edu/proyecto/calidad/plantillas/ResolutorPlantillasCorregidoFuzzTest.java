package edu.proyecto.calidad.plantillas;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.HashMap;
import java.util.Map;
import java.util.stream.Stream;

import com.code_intelligence.jazzer.junit.FuzzTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

/**
 * Fuzz target de V-B ({@link ResolutorPlantillasCorregido}) — fase F-06.
 *
 * <p>Evalúa la misma propiedad que el fuzz de V-A con el mismo oráculo
 * compartido ({@link OraculoNoReinterpretacion}) y las mismas semillas:
 * las expresiones del dato no confiable deben permanecer literales. En
 * V-B se espera que todas las semillas pasen y que una corrida acotada
 * no produzca violaciones; esa ausencia no demuestra ausencia de
 * defectos.</p>
 */
class ResolutorPlantillasCorregidoFuzzTest {

    private static final String PLANTILLA = "Hola, ${mayusculas:nombre}";
    private static final String CLAVE = "nombre";

    private final ResolutorPlantillasCorregido resolvedor = new ResolutorPlantillasCorregido();

    static Stream<Arguments> datosSemilla() {
        // Sin semilla "": ver nota en ResolutorPlantillasFuzzTest (ENV-003).
        // Semilla larga (revisión de cierre F-06B): ejercita en regresión la
        // ruta de rechazo por longitud, sin duplicar el resto de semillas.
        return Stream.of(
                Arguments.of("ana"),
                Arguments.of("ana ${minusculas:XYZ}"),
                Arguments.of("ana ${girar:xy}"),
                Arguments.of("a ${b"),
                Arguments.of("a } b"),
                Arguments.of("z".repeat(ResolutorPlantillasCorregido.LONGITUD_MAXIMA_VALOR + 1)));
    }

    @MethodSource("datosSemilla")
    @FuzzTest
    void datoNoSeReinterpretaEnCorregido(String dato) {
        if (dato == null) {
            dato = "";
        }
        Map<String, String> contexto = new HashMap<>();
        contexto.put(CLAVE, dato);
        if (dato.length() > ResolutorPlantillasCorregido.LONGITUD_MAXIMA_VALOR) {
            // Ruta de rechazo por longitud (F-06B): el oráculo no la modela;
            // se exige el rechazo explícito en lugar de la comparación.
            final String datoFinal = dato;
            assertThrows(IllegalArgumentException.class,
                    () -> resolvedor.resolver(PLANTILLA, contexto),
                    "El dato sobre el límite debe rechazarse. Longitud: " + datoFinal.length());
            return;
        }
        String obtenido = resolvedor.resolver(PLANTILLA, contexto);
        String esperado = OraculoNoReinterpretacion.referenciaUnaPasada(PLANTILLA, CLAVE, dato);
        assertEquals(esperado, obtenido,
                "La salida reinterpreta expresiones del dato no confiable. Dato: <" + dato + ">");
    }
}
