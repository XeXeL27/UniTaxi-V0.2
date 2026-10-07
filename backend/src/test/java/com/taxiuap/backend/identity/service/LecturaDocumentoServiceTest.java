package com.taxiuap.backend.identity.service;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import com.sun.net.httpserver.HttpServer;
import com.taxiuap.backend.identity.dto.LecturaDocumentoResponse;
import com.taxiuap.backend.identity.dto.LecturaSelfieResponse;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.enums.DocumentoIdentidad;
import com.taxiuap.backend.identity.enums.LadoDocumento;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.ia.ClienteClaude;
import com.taxiuap.backend.shared.ia.ClienteGemini;
import com.taxiuap.backend.shared.ia.LectorIa;

import tools.jackson.databind.json.JsonMapper;

/** Lectura con un Gemini falso (servidor HTTP local). Todos los datos son inventados. */
class LecturaDocumentoServiceTest {

    private HttpServer servidor;
    private final AtomicReference<String> lecturaJson = new AtomicReference<>();
    private final AtomicInteger estado = new AtomicInteger(200);
    private final AtomicInteger llamadas = new AtomicInteger();
    private final AtomicReference<String> ocupado = new AtomicReference<>();
    private final java.util.List<String> modelosPedidos = new java.util.concurrent.CopyOnWriteArrayList<>();
    private LecturaDocumentoService servicio;

    @BeforeEach
    void iniciar() throws IOException {
        servidor = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        servidor.createContext("/", intercambio -> {
            if ("GET".equals(intercambio.getRequestMethod())) {
                // Lista de modelos para la cadena de respaldo.
                byte[] lista = "{\"models\":[{\"name\":\"models/gemini-3.8-flash\"},{\"name\":\"models/gemini-3.6-flash\"},{\"name\":\"models/gemini-3.6-flash-lite\"}]}"
                        .getBytes(StandardCharsets.UTF_8);
                intercambio.getResponseHeaders().add("Content-Type", "application/json");
                intercambio.sendResponseHeaders(200, lista.length);
                try (OutputStream salida = intercambio.getResponseBody()) {
                    salida.write(lista);
                }
                return;
            }
            llamadas.incrementAndGet();
            modelosPedidos.add(intercambio.getRequestURI().getPath());
            boolean saturado = ocupado.get() != null && intercambio.getRequestURI().getPath().contains(ocupado.get());
            if (saturado) {
                byte[] error = "{\"error\":{\"code\":503,\"message\":\"high demand\"}}".getBytes(StandardCharsets.UTF_8);
                intercambio.getResponseHeaders().add("Content-Type", "application/json");
                intercambio.sendResponseHeaders(503, error.length);
                try (OutputStream salida = intercambio.getResponseBody()) {
                    salida.write(error);
                }
                return;
            }
            String cuerpo = estado.get() == 200
                    ? "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":" + JsonMapper.builder().build()
                            .writeValueAsString(lecturaJson.get()) + "}]}}]}"
                    : "{\"error\":{\"code\":403,\"message\":\"denegado\"}}";
            byte[] bytes = cuerpo.getBytes(StandardCharsets.UTF_8);
            intercambio.getResponseHeaders().add("Content-Type", "application/json");
            intercambio.sendResponseHeaders(estado.get(), bytes.length);
            try (OutputStream salida = intercambio.getResponseBody()) {
                salida.write(bytes);
            }
        });
        servidor.start();
        String url = "http://127.0.0.1:" + servidor.getAddress().getPort();
        // Sin llave de Claude: estas pruebas ejercitan el respaldo con Gemini (ver ClienteClaudeTest).
        servicio = new LecturaDocumentoService(new LectorIa(new ClienteClaude("", "claude-haiku-4-5", "http://127.0.0.1:9", 5),
                new ClienteGemini("llave", "gemini-flash-latest", url, "", 5)),
                JsonMapper.builder().build(), 40);
    }

    @AfterEach
    void detener() {
        servidor.stop(0);
    }

    private static MockMultipartFile foto(String contenido) {
        return new MockMultipartFile("foto", "foto.jpg", "image/jpeg", contenido.getBytes(StandardCharsets.UTF_8));
    }

    private LecturaDocumentoResponse leer(String json, String contenido, DocumentoIdentidad documento,
            LadoDocumento lado) {
        lecturaJson.set(json);
        return servicio.leer(foto(contenido), documento, lado, "10.0.0.1");
    }

    private static final String CARNET_ANVERSO_NUEVO = """
            {"documento":"CARNET_ANVERSO","formato":"NUEVO","legible":true,"numero":"7654321","complemento":"1A",
             "nombres":"MARÍA ELENA","apellidos":"ROJAS VACA","nombreCompleto":"MARÍA ELENA ROJAS VACA",
             "nombreSeparado":true,"nombreCortado":false,"fechaNacimiento":"1995-04-12","vencimiento":"2032-05-20"}""";
    private static final String CARNET_REVERSO_NUEVO = """
            {"documento":"CARNET_REVERSO","formato":"NUEVO","legible":true,"numero":"7654321",
             "nombres":"MARIA ELENA","apellidos":"ROJAS VACA","nombreSeparado":true,"nombreCortado":false,
             "fechaNacimiento":"1995-04-12"}""";
    private static final String LICENCIA_ANVERSO = """
            {"documento":"LICENCIA_ANVERSO","formato":"LICENCIA","legible":true,"numero":"7654321","complemento":"1A",
             "nombres":"MARIA ELENA","apellidos":"ROJAS VACA","nombreSeparado":true,"nombreCortado":false,
             "categoria":"M","vencimiento":"2031-01-01"}""";
    private static final String LICENCIA_REVERSO = """
            {"documento":"LICENCIA_REVERSO","formato":"LICENCIA","legible":true,"numero":"7654321",
             "nombreSeparado":false,"nombreCortado":false,"categoria":"M","vencimiento":"2031-01-01"}""";

    @Test
    void leeElAnversoDelCarnetNuevo() {
        LecturaDocumentoResponse lectura = leer(CARNET_ANVERSO_NUEVO, "a", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        assertTrue(lectura.disponible());
        assertTrue(lectura.aceptada());
        assertEquals("7654321", lectura.numero());
        assertEquals("1A", lectura.complemento());
        assertEquals("MARÍA ELENA", lectura.nombres());
        assertEquals("ROJAS VACA", lectura.apellidos());
    }

    @Test
    void laMismaFotoNoSeVuelveAEnviarAGemini() {
        leer(CARNET_ANVERSO_NUEVO, "a", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        leer(CARNET_ANVERSO_NUEVO, "a", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        assertEquals(1, llamadas.get());
    }

    @Test
    void rechazaElLadoEquivocado() {
        LecturaDocumentoResponse lectura = leer(CARNET_REVERSO_NUEVO, "r", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        assertTrue(lectura.disponible());
        assertFalse(lectura.aceptada());
        assertTrue(lectura.motivo().contains("reverso"));
    }

    @Test
    void rechazaLaFotoIlegibleConElMotivoDeGemini() {
        LecturaDocumentoResponse lectura = leer("""
                {"documento":"CARNET_ANVERSO","formato":"NUEVO","legible":false,
                 "problema":"La foto esta borrosa","nombreSeparado":false,"nombreCortado":false}""", "b",
                DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        assertFalse(lectura.aceptada());
        assertEquals("La foto esta borrosa", lectura.motivo());
    }

    @Test
    void elCarnetAntiguoTraeElCorteQuePropusoGemini() {
        LecturaDocumentoResponse lectura = leer("""
                {"documento":"CARNET_REVERSO","formato":"ANTIGUO","legible":true,"numero":"7654321",
                 "nombreCompleto":"MARIA ELENA ROJAS VACA","nombres":"MARIA ELENA","apellidos":"ROJAS VACA",
                 "nombreSeparado":false,"nombreCortado":false,"fechaNacimiento":"1995-04-12"}""", "v",
                DocumentoIdentidad.CARNET, LadoDocumento.REVERSO);
        assertTrue(lectura.aceptada());
        assertFalse(lectura.nombreSeparado());
        assertEquals("MARIA ELENA ROJAS VACA", lectura.nombreCompleto());
        assertEquals("MARIA ELENA", lectura.nombres());
        assertEquals("ROJAS VACA", lectura.apellidos());
    }

    @Test
    void unCorteConOtrasPalabrasSeDescarta() {
        LecturaDocumentoResponse lectura = leer("""
                {"documento":"CARNET_REVERSO","formato":"ANTIGUO","legible":true,"numero":"7654321",
                 "nombreCompleto":"MARIA ELENA ROJAS VACA","nombres":"MARIA","apellidos":"ROJAS",
                 "nombreSeparado":false,"nombreCortado":false,"fechaNacimiento":"1995-04-12"}""", "w",
                DocumentoIdentidad.CARNET, LadoDocumento.REVERSO);
        assertTrue(lectura.aceptada());
        assertEquals(null, lectura.nombres());
        assertEquals("MARIA ELENA ROJAS VACA", lectura.nombreCompleto());
    }

    @Test
    void sinGeminiLaAppLeeConSuLector() {
        estado.set(403);
        LecturaDocumentoResponse lectura = leer(CARNET_ANVERSO_NUEVO, "a", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        assertFalse(lectura.disponible());
    }

    @Test
    void verificaQueLosDatosDelRegistroSeanLosLeidos() {
        leer(CARNET_ANVERSO_NUEVO, "a", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        leer(CARNET_REVERSO_NUEVO, "r", DocumentoIdentidad.CARNET, LadoDocumento.REVERSO);
        String a = LecturaDocumentoService.huella(foto("a"));
        String r = LecturaDocumentoService.huella(foto("r"));
        LocalDate nacimiento = LocalDate.of(1995, 4, 12);
        assertDoesNotThrow(() -> servicio.verificarCarnet(a, r, "7654321", "1A", nacimiento, "MARIA ELENA", "ROJAS VACA"));
        assertThrows(NegocioException.class,
                () -> servicio.verificarCarnet(a, r, "7654322", "1A", nacimiento, "MARIA ELENA", "ROJAS VACA"));
        assertThrows(NegocioException.class,
                () -> servicio.verificarCarnet(a, r, "7654321", "1A", nacimiento, "MARIA", "ROJAS VACA"));
        assertThrows(NegocioException.class,
                () -> servicio.verificarCarnet(a, r, "7654321", "1A", nacimiento.plusDays(1), "MARIA ELENA", "ROJAS VACA"));
        // Fotos que el servidor no leyo (ML Kit en el telefono): no se compara.
        assertDoesNotThrow(() -> servicio.verificarCarnet("x", "y", "1111111", null, nacimiento, "OTRO", "NOMBRE"));
    }

    @Test
    void laLicenciaLeidaQueCoincideConElCarnetApruebaAlConductor() {
        leer(LICENCIA_ANVERSO, "la", DocumentoIdentidad.LICENCIA, LadoDocumento.ANVERSO);
        leer(LICENCIA_REVERSO, "lr", DocumentoIdentidad.LICENCIA, LadoDocumento.REVERSO);
        String a = LecturaDocumentoService.huella(foto("la"));
        String r = LecturaDocumentoService.huella(foto("lr"));
        Persona persona = new Persona();
        persona.setCi("7654321");
        persona.setComplementoCi("1A");
        persona.setNombres("María Elena");
        persona.setApellidos("Rojas Vaca");
        assertTrue(servicio.licenciaCoincide(a, r, persona));
        persona.setApellidos("Rojas");
        assertFalse(servicio.licenciaCoincide(a, r, persona));
        assertDoesNotThrow(() -> servicio.verificarLicencia(a, r, "7654321-1A", "M", LocalDate.of(2031, 1, 1)));
        assertThrows(NegocioException.class,
                () -> servicio.verificarLicencia(a, r, "7654321-1A", "B", LocalDate.of(2031, 1, 1)));
    }

    @Test
    void siElFlashMasNuevoEstaSaturadoSePruebaElAnterior() {
        ocupado.set("gemini-flash-latest");
        LecturaDocumentoResponse lectura = leer(CARNET_ANVERSO_NUEVO, "s", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        assertTrue(lectura.aceptada());
        assertEquals(2, modelosPedidos.size());
        assertTrue(modelosPedidos.get(1).contains("gemini-3.6-flash:"), modelosPedidos.toString());
        // El saturado se salta en la siguiente lectura.
        leer(CARNET_ANVERSO_NUEVO, "t", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        assertEquals(3, modelosPedidos.size());
        assertTrue(modelosPedidos.get(2).contains("gemini-3.6-flash:"));
    }

    // ---------------------------------------------------------------- vencimiento

    @Test
    void elAnversoTraeHastaCuandoValeElCarnet() {
        LecturaDocumentoResponse lectura = leer(CARNET_ANVERSO_NUEVO, "a", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        assertEquals(LocalDate.of(2032, 5, 20), lectura.vencimiento());
        assertEquals(LocalDate.of(2032, 5, 20), servicio.vencimientoCarnet(LecturaDocumentoService.huella(foto("a"))));
    }

    @Test
    void rechazaElCarnetVencidoConLaFecha() {
        LecturaDocumentoResponse lectura = leer(CARNET_ANVERSO_NUEVO.replace("2032-05-20", "2020-03-15"), "vencido",
                DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        assertTrue(lectura.disponible());
        assertFalse(lectura.aceptada());
        assertTrue(lectura.motivo().contains("15/03/2020"), lectura.motivo());
        assertEquals(LocalDate.of(2020, 3, 15), lectura.vencimiento());
    }

    @Test
    void elCarnetIndefinidoSeAcepta() {
        LecturaDocumentoResponse lectura = leer(CARNET_ANVERSO_NUEVO.replace("\"vencimiento\":\"2032-05-20\"",
                "\"sinVencimiento\":true"), "indefinido", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        assertTrue(lectura.aceptada());
        assertEquals(null, lectura.vencimiento());
    }

    @Test
    void sinLaFechaDeVencimientoPideOtraFotoDelAnverso() {
        LecturaDocumentoResponse lectura = leer(CARNET_ANVERSO_NUEVO.replace(",\"vencimiento\":\"2032-05-20\"", ""),
                "sinfecha", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        assertFalse(lectura.aceptada());
        assertTrue(lectura.motivo().contains("Válida hasta"), lectura.motivo());
    }

    @Test
    void rechazaLaLicenciaVencida() {
        LecturaDocumentoResponse lectura = leer(LICENCIA_REVERSO.replace("2031-01-01", "2021-01-01"), "lv",
                DocumentoIdentidad.LICENCIA, LadoDocumento.REVERSO);
        assertFalse(lectura.aceptada());
        assertTrue(lectura.motivo().startsWith("Tu licencia venció"), lectura.motivo());
    }

    // ---------------------------------------------------------------- foto con el carnet

    private static final String SELFIE_BIEN = """
            {"caraVisible":true,"carnetVisible":true,"ladoCarnet":"ANVERSO","numero":"7654321",
             "pantallaOImpresion":false,"caraCoincide":true,"legible":true}""";

    private LecturaSelfieResponse selfie(String json, String contenido, String anverso) {
        lecturaJson.set(json);
        return servicio.leerSelfie(foto(contenido), anverso == null ? null : foto(anverso), "10.0.0.1");
    }

    @Test
    void aceptaLaFotoConElCarnetYLaGuardaParaElRegistro() {
        leer(CARNET_ANVERSO_NUEVO, "a", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        LecturaSelfieResponse lectura = selfie(SELFIE_BIEN, "s", "a");
        assertTrue(lectura.aceptada());
        assertEquals("7654321", lectura.numero());
        assertEquals(null, lectura.observacion());
        LecturaSelfieResponse guardada = servicio.selfie(LecturaDocumentoService.huella(foto("s")),
                LecturaDocumentoService.huella(foto("a")));
        assertEquals("7654321", guardada.numero());
    }

    @Test
    void laCaraDistintaSeAceptaConObservacion() {
        LecturaSelfieResponse lectura = selfie(SELFIE_BIEN.replace("\"caraCoincide\":true", "\"caraCoincide\":false"),
                "otra", null);
        assertTrue(lectura.aceptada());
        assertTrue(lectura.observacion().contains("no se parece"));
    }

    @Test
    void rechazaLaFotoConElReversoDelCarnet() {
        LecturaSelfieResponse lectura = selfie(SELFIE_BIEN.replace("\"ANVERSO\"", "\"REVERSO\""), "rev", null);
        assertFalse(lectura.aceptada());
        assertTrue(lectura.motivo().contains("lado de tu carnet que tiene tu foto"));
    }

    @Test
    void rechazaOtroCarnetDelDeLasFotos() {
        leer(CARNET_ANVERSO_NUEVO, "a", DocumentoIdentidad.CARNET, LadoDocumento.ANVERSO);
        LecturaSelfieResponse lectura = selfie(SELFIE_BIEN.replace("7654321", "1234567"), "otro", "a");
        assertFalse(lectura.aceptada());
        assertTrue(lectura.motivo().contains("no es el mismo"));
    }

    @Test
    void sinGeminiLaFotoConElCarnetQuedaSinRevisar() {
        estado.set(403);
        LecturaSelfieResponse lectura = selfie(SELFIE_BIEN, "s", null);
        assertFalse(lectura.disponible());
        assertEquals(null, servicio.selfie(LecturaDocumentoService.huella(foto("s")), null));
    }
}
