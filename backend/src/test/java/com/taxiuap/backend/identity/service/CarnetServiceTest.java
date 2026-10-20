package com.taxiuap.backend.identity.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.mock.web.MockMultipartFile;

import com.taxiuap.backend.identity.dto.LecturaSelfieResponse;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Rol;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.exception.NegocioException;

/**
 * Lo que le falta del carnet a una cuenta se decide con los archivos que de verdad estan en el servidor:
 * con las rutas anotadas pero sin los archivos, la app debe volver a pedir el anverso y el reverso.
 * Datos inventados.
 */
class CarnetServiceTest {

    private static final String ANVERSO = "personas/9_1234567/general/carnet/carnet_anverso.jpg";
    private static final String REVERSO = "personas/9_1234567/general/carnet/carnet_reverso.jpg";

    private final UsuarioRepository usuarios = mock(UsuarioRepository.class);
    private final AlmacenamientoArchivos archivos = mock(AlmacenamientoArchivos.class);
    private final LecturaDocumentoService lecturas = mock(LecturaDocumentoService.class);
    private final CarnetService servicio = new CarnetService(usuarios, mock(GestionPersonaService.class), archivos,
            mock(CredencialesCorreoService.class), mock(CuentaUsuarioService.class), mock(PermisoEdicionService.class),
            mock(ConductorRepository.class), lecturas);
    private Persona persona;
    private Usuario usuario;

    @BeforeEach
    void preparar() {
        persona = new Persona();
        persona.setId(9L);
        persona.setCi("1234567");
        persona.setCarnetAnversoUrl(ANVERSO);
        persona.setCarnetReversoUrl(REVERSO);
        Rol rol = new Rol();
        rol.setCodigo("PASAJERO");
        usuario = new Usuario();
        usuario.setId(21L);
        usuario.setPersona(persona);
        usuario.setRol(rol);
        when(usuarios.findById(21L)).thenReturn(Optional.of(usuario));
    }

    @Test
    void conLasDosFotosEnElServidorSoloFaltaLaFotoConElCarnet() {
        when(archivos.existe(ANVERSO)).thenReturn(true);
        when(archivos.existe(REVERSO)).thenReturn(true);

        assertEquals("SELFIE", servicio.respuesta(usuario).carnetPendiente());
    }

    @Test
    void sinElArchivoDelReversoPideOtraVezLasFotosDelCarnet() {
        when(archivos.existe(ANVERSO)).thenReturn(true);
        when(archivos.existe(REVERSO)).thenReturn(false);

        assertEquals("CARNET", servicio.respuesta(usuario).carnetPendiente());
        assertFalse(servicio.tieneCarnet(persona));
    }

    @Test
    void sinElArchivoDelAnversoPideOtraVezLasFotosDelCarnet() {
        when(archivos.existe(ANVERSO)).thenReturn(false);
        when(archivos.existe(REVERSO)).thenReturn(true);

        assertEquals("CARNET", servicio.respuesta(usuario).carnetPendiente());
    }

    @Test
    void conLaFotoConElCarnetNoLeFaltaNada() {
        persona.setCarnetSelfieUrl("personas/9_1234567/general/carnet/carnet_selfie.jpg");

        assertNull(servicio.respuesta(usuario).carnetPendiente());
    }

    @Test
    void soloLaFotoConElCarnetSinLosArchivosDelCarnetExplicaQueDebeTomarlosDeNuevo() {
        when(archivos.existe(anyString())).thenReturn(false);
        MockMultipartFile selfie = new MockMultipartFile("selfie", "selfie.jpg", "image/jpeg", new byte[] {1, 2, 3});

        NegocioException error = assertThrows(NegocioException.class,
                () -> servicio.actualizarCuenta(21L, null, null, selfie));

        assertEquals(CarnetService.MENSAJE_FALTAN_FOTOS, error.getMessage());
    }

    @Test
    void revisarLaFotoSinLosArchivosDelCarnetNoLlamaALaIa() {
        when(archivos.existe(anyString())).thenReturn(false);
        MockMultipartFile selfie = new MockMultipartFile("selfie", "selfie.jpg", "image/jpeg", new byte[] {1, 2, 3});

        NegocioException error = assertThrows(NegocioException.class,
                () -> servicio.revisarSelfieCuenta(21L, selfie));

        assertEquals(CarnetService.MENSAJE_FALTAN_FOTOS, error.getMessage());
        verify(lecturas, never()).leerSelfie(any(byte[].class), anyString(), any(), any());
    }

    @Test
    void revisarLaFotoConOtroCarnetLaRechaza() {
        when(archivos.existe(anyString())).thenReturn(true);
        when(archivos.leer(ANVERSO)).thenReturn(new ByteArrayResource(new byte[] {9, 9}));
        when(lecturas.leerSelfie(any(byte[].class), anyString(), any(), eq("usuario:21")))
                .thenReturn(new LecturaSelfieResponse(true, true, null, "7654321", null));
        MockMultipartFile selfie = new MockMultipartFile("selfie", "selfie.jpg", "image/jpeg", new byte[] {1, 2, 3});

        LecturaSelfieResponse lectura = servicio.revisarSelfieCuenta(21L, selfie);

        assertFalse(lectura.aceptada());
        assertTrue(lectura.motivo().contains("1234567"));
    }

    @Test
    void revisarLaFotoConSuCarnetLaAcepta() {
        when(archivos.existe(anyString())).thenReturn(true);
        when(archivos.leer(ANVERSO)).thenReturn(new ByteArrayResource(new byte[] {9, 9}));
        when(lecturas.leerSelfie(any(byte[].class), anyString(), any(), eq("usuario:21")))
                .thenReturn(new LecturaSelfieResponse(true, true, null, "1234567", null));
        MockMultipartFile selfie = new MockMultipartFile("selfie", "selfie.jpg", "image/jpeg", new byte[] {1, 2, 3});

        assertTrue(servicio.revisarSelfieCuenta(21L, selfie).aceptada());
    }
}
