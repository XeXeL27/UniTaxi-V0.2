package com.taxiuap.backend.identity.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.taxiuap.backend.identity.dto.ActualizarLimiteAdelantoCompraRequest;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.pricing.entity.BilleteraConductor;
import com.taxiuap.backend.pricing.repository.BilleteraConductorRepository;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;

@ExtendWith(MockitoExtension.class)
class PerfilConductorLimiteAdelantoTest {

    @Mock private ConductorRepository conductorRepository;
    @Mock private BilleteraConductorRepository billeteraRepository;
    @Mock private PermisoEdicionService permisoEdicionService;
    @Mock private CuentaUsuarioService cuentaUsuarioService;
    @Mock private AlmacenamientoArchivos almacenamientoArchivos;

    private PerfilConductorService service;
    private Conductor conductor;

    @BeforeEach
    void setUp() {
        Persona persona = new Persona();
        persona.setNombres("Ana");
        persona.setApellidos("Repartidora");
        Usuario usuario = new Usuario();
        usuario.setId(10L);
        usuario.setPersona(persona);
        conductor = new Conductor();
        conductor.setId(20L);
        conductor.setUsuario(usuario);
        conductor.setNumeroLicencia("123");
        conductor.setCategoriaLicencia("M");
        conductor.setLimiteAdelantoCompra(new BigDecimal("20.00"));

        service = new PerfilConductorService(conductorRepository, billeteraRepository, permisoEdicionService,
                cuentaUsuarioService, almacenamientoArchivos);
        when(conductorRepository.findByUsuarioId(10L)).thenReturn(Optional.of(conductor));
        when(billeteraRepository.findByConductorId(20L)).thenReturn(Optional.<BilleteraConductor>empty());
        when(almacenamientoArchivos.existe(null)).thenReturn(false);
    }

    @Test
    void actualizaSoloElLimiteDeAdelanto() {
        var respuesta = service.actualizarLimiteAdelantoCompra(10L,
                new ActualizarLimiteAdelantoCompraRequest(new BigDecimal("100.50"), "secreto"));

        assertEquals(new BigDecimal("100.50"), conductor.getLimiteAdelantoCompra());
        assertEquals("ANA", conductor.getUsuario().getPersona().getNombres());
        assertEquals("123", conductor.getNumeroLicencia());
        assertEquals(new BigDecimal("100.50"), respuesta.limiteAdelantoCompra());
        verify(cuentaUsuarioService).confirmarContrasena(conductor.getUsuario(), "secreto");
    }
}
