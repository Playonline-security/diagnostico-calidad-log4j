package edu.proyecto.calidad.plantillas;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.HashMap;
import java.util.Map;
import java.util.stream.Stream;

import com.code_intelligence.jazzer.junit.FuzzTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

/**
 * Fuzz target de V-A ({@link ResolutorPlantillas}) — fases F-04/F-06.
 *
 * <p>Propiedad de seguridad evaluada: <strong>las expresiones introducidas
 * por el dato no confiable deben permanecer como texto literal y no ser
 * interpretadas como instrucciones de plantilla</strong>. El oráculo
 * ({@link OraculoNoReinterpretacion}, compartido con el fuzz de V-B)
 * compara la salida con un resultado de referencia calculado de forma
 * independiente, sin reutilizar el algoritmo de reexpansión de V-A.</p>
 *
 * <p>Semilla de referencia {@code ana ${minusculas:XYZ}}: caso conocido
 * (TEST-006) que incumple la propiedad en V-A. Se distingue de cualquier
 * contraejemplo adicional que Jazzer genere. Las semillas de borde
 * ({@code ""}, {@code a ${b}, {@code a } b}) fijan por ejecución el
 * contrato del oráculo verificado por lectura en la revisión posterior
 * de F-04.</p>
 */
class ResolutorPlantillasFuzzTest {

    private static final String PLANTILLA = "Hola, ${mayusculas:nombre}";
    private static final String CLAVE = "nombre";

    private final ResolutorPlantillas resolvedor = new ResolutorPlantillas();

    static Stream<Arguments> datosSemilla() {
        // Sin semilla "": junit-jupiter-params 5.10.5 no ofrece Named y el
        // nombre de invocación en blanco aborta el contenedor (ENV-003).
        // El dato vacío se cubre en TEST-VB-08 y en la mutación del fuzzer.
        return Stream.of(
                Arguments.of("ana"),
                Arguments.of("ana ${minusculas:XYZ}"),
                Arguments.of("ana ${girar:xy}"),
                Arguments.of("a ${b"),
                Arguments.of("a } b"));
    }

    @MethodSource("datosSemilla")
    @FuzzTest
    void datoNoSeReinterpreta(String dato) {
        if (dato == null) {
            dato = "";
        }
        Map<String, String> contexto = new HashMap<>();
        contexto.put(CLAVE, dato);
        String obtenido = resolvedor.resolver(PLANTILLA, contexto);
        String esperado = OraculoNoReinterpretacion.referenciaUnaPasada(PLANTILLA, CLAVE, dato);
        assertEquals(esperado, obtenido,
                "La salida reinterpreta expresiones del dato no confiable. Dato: <" + dato + ">");
    }

    // Oráculo en OraculoNoReinterpretacion (compartido con el fuzz de V-B, F-06).
}
