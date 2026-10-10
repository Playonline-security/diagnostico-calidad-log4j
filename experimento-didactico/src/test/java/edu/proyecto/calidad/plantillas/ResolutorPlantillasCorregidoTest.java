package edu.proyecto.calidad.plantillas;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Batería de caracterización de V-B ({@link ResolutorPlantillasCorregido}).
 *
 * Cada resultado esperado se definió antes de ejecutar, a partir del
 * contrato de V-B: una sola pasada, valores como texto literal, funciones
 * autorizadas y literales para lo desconocido o sin cerrar.
 */
class ResolutorPlantillasCorregidoTest {

    private final ResolutorPlantillasCorregido resolvedor = new ResolutorPlantillasCorregido();

    private Map<String, String> contexto(String clave, String valor) {
        Map<String, String> mapa = new HashMap<>();
        mapa.put(clave, valor);
        return mapa;
    }

    @Test
    @DisplayName("TEST-VB-01: función legítima mayúsculas")
    void funcionLegitimaMayusculas() {
        String obtenido = resolvedor.resolver("Hola, ${mayusculas:mundo}", contexto("mundo", "mundo"));
        assertEquals("Hola, MUNDO", obtenido);
    }

    @Test
    @DisplayName("TEST-VB-02: función legítima minúsculas")
    void funcionLegitimaMinusculas() {
        String obtenido = resolvedor.resolver("Valor ${minusculas:ABC} fin", new HashMap<>());
        assertEquals("Valor abc fin", obtenido);
    }

    @Test
    @DisplayName("TEST-VB-03: función legítima longitud")
    void funcionLegitimaLongitud() {
        String obtenido = resolvedor.resolver("N=${longitud:Hola}", new HashMap<>());
        assertEquals("N=4", obtenido);
    }

    @Test
    @DisplayName("TEST-VB-04: el dato con expresión no se reinterpreta")
    void datoConExpresionNoSeReinterpreta() {
        Map<String, String> contexto = contexto("nombre", "ana ${minusculas:XYZ}");
        String obtenido = resolvedor.resolver("Hola, ${mayusculas:nombre}", contexto);
        assertEquals("Hola, ANA ${minusculas:XYZ}", obtenido);
    }

    @Test
    @DisplayName("TEST-VB-05: función desconocida queda literal")
    void funcionDesconocidaQuedaLiteral() {
        String obtenido = resolvedor.resolver("Valor ${girar:xy} fin", new HashMap<>());
        assertEquals("Valor ${girar:xy} fin", obtenido);
    }

    @Test
    @DisplayName("TEST-VB-06: expresión sin cerrar queda literal")
    void expresionSinCerrarQuedaLiteral() {
        String obtenido = resolvedor.resolver("Hola ${mayusculas:abc", new HashMap<>());
        assertEquals("Hola ${mayusculas:abc", obtenido);
    }

    @Test
    @DisplayName("TEST-VB-07: plantilla vacía produce cadena vacía")
    void plantillaVaciaProduceCadenaVacia() {
        assertEquals("", resolvedor.resolver("", contexto("nombre", "ana")));
    }

    @Test
    @DisplayName("TEST-VB-08: valor vacío produce texto vacío")
    void valorVacioProduceTextoVacio() {
        String obtenido = resolvedor.resolver("Hola, ${mayusculas:nombre}", contexto("nombre", ""));
        assertEquals("Hola, ", obtenido);
    }

    @Test
    @DisplayName("TEST-VB-09: expresión incompleta en el dato queda inerte")
    void expresionIncompletaEnDatoQuedaInerte() {
        Map<String, String> contexto = contexto("nombre", "a ${b");
        String obtenido = resolvedor.resolver("Hola, ${mayusculas:nombre}", contexto);
        assertEquals("Hola, A ${B", obtenido);
    }

    @Test
    @DisplayName("TEST-VB-10: llave de cierre aislada en el dato queda literal")
    void llaveAisladaEnDatoQuedaLiteral() {
        Map<String, String> contexto = contexto("nombre", "a } b");
        String obtenido = resolvedor.resolver("Hola, ${mayusculas:nombre}", contexto);
        assertEquals("Hola, A } B", obtenido);
    }

    @Test
    @DisplayName("TEST-VB-11: clave ausente usa el texto como literal")
    void claveAusenteUsaTextoLiteral() {
        String obtenido = resolvedor.resolver("Valor ${mayusculas:ausente}", new HashMap<>());
        assertEquals("Valor AUSENTE", obtenido);
    }

    @Test
    @DisplayName("TEST-VB-12: anidamiento en plantilla autorizada")
    void anidamientoEnPlantillaAutorizada() {
        String obtenido = resolvedor.resolver("R=${mayusculas:${minusculas:ABC}}", new HashMap<>());
        assertEquals("R=ABC", obtenido);
    }

    @Test
    @DisplayName("TEST-VB-13: dato largo sin expresiones se procesa lineal")
    void datoLargoSinExpresiones() {
        String largo = "a".repeat(5000);
        String obtenido = resolvedor.resolver("Hola, ${mayusculas:nombre}", contexto("nombre", largo));
        assertEquals("Hola, " + "A".repeat(5000), obtenido);
        assertEquals(5006, obtenido.length());
    }

    @Test
    @DisplayName("TEST-VB-14: contratos nulos")
    void contratosNulos() {
        assertThrows(NullPointerException.class,
                () -> resolvedor.resolver(null, new HashMap<>()));
        assertEquals("Hola, ANA", resolvedor.resolver("Hola, ${mayusculas:ana}", null));
    }

    @Test
    @DisplayName("TEST-VB-15: referencia simple conserva la expresión del valor")
    void referenciaSimpleConservaExpresionDelValor() {
        assertEquals("ana", resolvedor.resolver("${nombre}", contexto("nombre", "ana")));
        assertEquals("${minusculas:XY}",
                resolvedor.resolver("${nombre}", contexto("nombre", "${minusculas:XY}")));
    }

    @Test
    @DisplayName("TEST-VB-16: valor en el límite exacto de longitud")
    void valorEnLimiteExacto() {
        String valor = "b".repeat(ResolutorPlantillasCorregido.LONGITUD_MAXIMA_VALOR);
        String obtenido = resolvedor.resolver("Hola, ${mayusculas:nombre}", contexto("nombre", valor));
        assertEquals("Hola, " + "B".repeat(ResolutorPlantillasCorregido.LONGITUD_MAXIMA_VALOR), obtenido);
    }

    @Test
    @DisplayName("TEST-VB-17: valor que supera el límite en uno se rechaza")
    void valorSobreLimiteSeRechaza() {
        String valor = "b".repeat(ResolutorPlantillasCorregido.LONGITUD_MAXIMA_VALOR + 1);
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> resolvedor.resolver("Hola, ${mayusculas:nombre}", contexto("nombre", valor)));
        assertTrue(error.getMessage().contains("longitud máxima"));
    }

    @Test
    @DisplayName("TEST-VB-18: plantilla en el límite exacto de longitud")
    void plantillaEnLimiteExacto() {
        String plantilla = "P".repeat(ResolutorPlantillasCorregido.LONGITUD_MAXIMA_PLANTILLA);
        assertEquals(plantilla, resolvedor.resolver(plantilla, new HashMap<>()));
    }

    @Test
    @DisplayName("TEST-VB-19: plantilla que supera el límite en uno se rechaza")
    void plantillaSobreLimiteSeRechaza() {
        String plantilla = "P".repeat(ResolutorPlantillasCorregido.LONGITUD_MAXIMA_PLANTILLA + 1);
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> resolvedor.resolver(plantilla, new HashMap<>()));
        assertTrue(error.getMessage().contains("longitud máxima"));
    }
}
