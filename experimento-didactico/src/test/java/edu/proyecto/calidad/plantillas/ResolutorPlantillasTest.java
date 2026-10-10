package edu.proyecto.calidad.plantillas;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Batería de caracterización de V-A ({@link ResolutorPlantillas}).
 *
 * <p>Cada prueba verifica un resultado concreto. Los casos de riesgo
 * describen la condición vulnerable como comportamiento observado y
 * esperado de V-A; ninguna prueba se escribe para fallar.</p>
 */
class ResolutorPlantillasTest {

    private final ResolutorPlantillas resolvedor = new ResolutorPlantillas();

    private Map<String, String> contexto(String clave, String valor) {
        Map<String, String> mapa = new HashMap<>();
        mapa.put(clave, valor);
        return mapa;
    }

    @Test
    @DisplayName("TEST-001: expansión simple con mayúsculas")
    void expansionSimpleConMayusculas() {
        String obtenido = resolvedor.resolver("Hola, ${mayusculas:mundo}", contexto("mundo", "mundo"));
        assertEquals("Hola, MUNDO", obtenido);
    }

    @Test
    @DisplayName("TEST-002: expansión simple con minúsculas")
    void expansionSimpleConMinusculas() {
        String obtenido = resolvedor.resolver("Valor ${minusculas:ABC} fin", new HashMap<>());
        assertEquals("Valor abc fin", obtenido);
    }

    @Test
    @DisplayName("TEST-003: función longitud sobre argumento limpio")
    void funcionLongitud() {
        String obtenido = resolvedor.resolver("N=${longitud:Hola}", new HashMap<>());
        assertEquals("N=4", obtenido);
    }

    @Test
    @DisplayName("TEST-004: función desconocida queda literal")
    void funcionDesconocidaQuedaLiteral() {
        String obtenido = resolvedor.resolver("Valor ${girar:xy} fin", new HashMap<>());
        assertEquals("Valor ${girar:xy} fin", obtenido);
    }

    @Test
    @DisplayName("TEST-005: expresión sin cerrar queda literal")
    void expresionSinCerrarQuedaLiteral() {
        String obtenido = resolvedor.resolver("Hola ${mayusculas:abc", new HashMap<>());
        assertEquals("Hola ${mayusculas:abc", obtenido);
    }

    @Test
    @DisplayName("TEST-006: reinterpretación de expresión incluida en el dato no confiable")
    void reinterpretacionDeExpresionEnDato() {
        Map<String, String> contexto = contexto("nombre", "ana ${minusculas:XYZ}");
        String obtenido = resolvedor.resolver("Hola, ${mayusculas:nombre}", contexto);
        assertEquals("Hola, ANA xyz", obtenido);
    }

    @Test
    @DisplayName("TEST-007: anidamiento escrito en la plantilla autorizada")
    void anidamientoEnPlantillaAutorizada() {
        String obtenido = resolvedor.resolver("R=${mayusculas:${minusculas:ABC}}", new HashMap<>());
        assertEquals("R=ABC", obtenido);
    }

    @Test
    @DisplayName("TEST-008: expresión desconocida del dato alcanza punto fijo")
    void expresionDesconocidaDelDatoAlcanzaPuntoFijo() {
        Map<String, String> contexto = contexto("nombre", "ana ${girar:xy}");
        String obtenido = resolvedor.resolver("Hola, ${mayusculas:nombre}", contexto);
        assertEquals("Hola, ANA ${girar:xy}", obtenido);
    }

    @Test
    @DisplayName("TEST-009: clave ausente usa el texto como literal")
    void claveAusenteUsaTextoLiteral() {
        String obtenido = resolvedor.resolver("Valor ${mayusculas:ausente}", new HashMap<>());
        assertEquals("Valor AUSENTE", obtenido);
    }

    @Test
    @DisplayName("TEST-010: referencia simple a variable")
    void referenciaSimpleAVariable() {
        assertEquals("ana", resolvedor.resolver("${nombre}", contexto("nombre", "ana")));
        assertEquals("xy", resolvedor.resolver("${nombre}", contexto("nombre", "${minusculas:XY}")));
    }

    @Test
    @DisplayName("TEST-011: plantilla nula falla rápido")
    void plantillaNulaFallaRapido() {
        assertThrows(NullPointerException.class,
                () -> resolvedor.resolver(null, new HashMap<>()));
    }

    @Test
    @DisplayName("TEST-012: contexto nulo se trata como vacío")
    void contextoNuloSeTrataComoVacio() {
        String obtenido = resolvedor.resolver("Hola, ${mayusculas:ana}", null);
        assertEquals("Hola, ANA", obtenido);
    }
}
