package com.taxiuap.backend.identity.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.PersonaAdminResponse;
import com.taxiuap.backend.identity.dto.RegistroPersonaAdminRequest;
import com.taxiuap.backend.identity.dto.RegistroPersonaAdminResponse;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionCarnet;
import com.taxiuap.backend.identity.enums.TipoRegistroPersona;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.institution.dto.DatosSigse;
import com.taxiuap.backend.institution.enums.SituacionVerificacion;
import com.taxiuap.backend.institution.service.EstudianteUapService;
import com.taxiuap.backend.shared.exception.NegocioException;

/** Registro de personas desde el panel: externa o estudiante (solo con el SIGSE) y fotos opcionales. Datos inventados. */
class RegistroPersonaAdminServiceTest {

    private final GestionPersonaService personas = mock(GestionPersonaService.class);
    private final PersonaRepository repositorio = mock(PersonaRepository.class);
    private final CuentaUsuarioService cuentas = mock(CuentaUsuarioService.class);
    private final CredencialesCorreoService correos = mock(CredencialesCorreoService.class);
    private final CarnetService carnet = mock(CarnetService.class);
    private final EstudianteUapService estudiantes = mock(EstudianteUapService.class);
    private final FotoPerfilService fotos = mock(FotoPerfilService.class);
    private final RegistroPersonaAdminService servicio = new RegistroPersonaAdminService(personas, repositorio, cuentas,
            correos, carnet, estudiantes, fotos, 7);
    private final LocalDate nacimiento = LocalDate.of(2001, 4, 8);
    private Persona persona;
    private Usuario usuario;

    @BeforeEach
    void preparar() {
        persona = new Persona();
        persona.setId(50L);
        persona.setNombres("PRUEBA");
        persona.setApellidos("DOS TRES");
        persona.setCorreo("prueba.dos@correo.test");
        usuario = new Usuario();
        usuario.setId(80L);
        usuario.setNombreUsuario("prueba.dos");
        usuario.setPersona(persona);
        when(personas.crear(any())).thenReturn(new PersonaAdminResponse(50L, "1234567", null, "PRUEBA", "DOS TRES",
                nacimiento, "prueba.dos@correo.test", "70000002", null, List.of(), null));
        when(repositorio.findById(50L)).thenReturn(Optional.of(persona));
        when(cuentas.nombreUsuarioLibre("prueba.dos@correo.test")).thenReturn("prueba.dos");
        when(cuentas.codificar(anyString())).thenReturn("hash");
        when(cuentas.crearUsuario(eq(persona), eq(RolSistema.PASAJERO), eq("prueba.dos"), eq("hash"))).thenReturn(usuario);
    }

    private RegistroPersonaAdminRequest pedido(TipoRegistroPersona tipo, String ru) {
        return new RegistroPersonaAdminRequest(tipo, ru, "1234567", null, "PRUEBA", "DOS TRES", nacimiento,
                "prueba.dos@correo.test", "70000002", null);
    }

    private static MockMultipartFile foto(String parte) {
        return new MockMultipartFile(parte, parte + ".jpg", "image/jpeg", new byte[] {1, 2, 3});
    }

    private static DatosSigse sigse(String nombres) {
        return new DatosSigse("26001", "1234567", nombres, "DOS", "TRES", LocalDate.of(2001, 4, 8), null, null,
                "INGENIERIA DE SISTEMAS", null, null, 2026, 2, null, true, null);
    }

    @Test
    void externa_sin_fotos_pide_el_carnet_al_ingresar_con_plazo() {
        RegistroPersonaAdminResponse respuesta = servicio.registrar(pedido(TipoRegistroPersona.EXTERNA, null),
                null, null, null);

        assertEquals("CARNET", respuesta.carnetPendiente());
        assertTrue(persona.getSelfieExigida());
        assertNotNull(persona.getPlazoSelfieCarnet());
        assertTrue(usuario.getContrasenaGenerada());
        verify(cuentas).crearPasajero(usuario);
        verify(correos).registradoPorAdmin(eq(usuario), anyString(), eq(false), eq("CARNET"));
        verify(estudiantes, never()).consultarMatriculado(any());
    }

    @Test
    void con_las_tres_fotos_queda_verificada_y_sin_plazo() {
        RegistroPersonaAdminResponse respuesta = servicio.registrar(pedido(TipoRegistroPersona.EXTERNA, null),
                foto("carnetAnverso"), foto("carnetReverso"), foto("carnetSelfie"));

        assertNull(respuesta.carnetPendiente());
        assertEquals(SituacionCarnet.VERIFICADO, persona.getSituacionCarnet());
        assertNull(persona.getPlazoSelfieCarnet());
        verify(carnet).reemplazarPorAdmin(eq(80L), any(), any(), any());
        verify(correos).registradoPorAdmin(eq(usuario), anyString(), eq(false), isNull());
    }

    @Test
    void solo_la_foto_con_el_carnet_no_alcanza() {
        assertThrows(NegocioException.class, () -> servicio.registrar(pedido(TipoRegistroPersona.EXTERNA, null),
                null, null, foto("carnetSelfie")));
        verify(personas, never()).crear(any());
    }

    @Test
    void estudiante_confirmado_por_el_sigse_queda_aprobado() {
        DatosSigse datos = sigse("PRUEBA");
        when(estudiantes.consultarMatriculado("26001")).thenReturn(datos);

        RegistroPersonaAdminResponse respuesta = servicio.registrar(pedido(TipoRegistroPersona.ESTUDIANTE_UAP, "26001"),
                null, null, null);

        assertTrue(respuesta.estudiante());
        assertEquals("INGENIERIA DE SISTEMAS", respuesta.carrera());
        verify(estudiantes).marcarEstudiante(persona, datos, SituacionVerificacion.APROBADA);
        verify(correos).registradoPorAdmin(eq(usuario), anyString(), eq(true), eq("CARNET"));
    }

    @Test
    void estudiante_con_otros_datos_en_el_sigse_no_se_registra() {
        when(estudiantes.consultarMatriculado("26001")).thenReturn(sigse("OTRO NOMBRE"));

        NegocioException e = assertThrows(NegocioException.class,
                () -> servicio.registrar(pedido(TipoRegistroPersona.ESTUDIANTE_UAP, "26001"), null, null, null));

        assertTrue(e.getMessage().contains("el nombre"));
        verify(personas, never()).crear(any());
        verify(estudiantes, never()).marcarEstudiante(any(), any(), any());
    }

    @Test
    void estudiante_sin_ru_no_se_registra() {
        assertThrows(NegocioException.class,
                () -> servicio.registrar(pedido(TipoRegistroPersona.ESTUDIANTE_UAP, " "), null, null, null));
        verify(personas, never()).crear(any());
    }
}
