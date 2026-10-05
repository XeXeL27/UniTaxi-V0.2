package com.taxiuap.backend.controller.admin;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.MediaType;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import com.taxiuap.backend.communication.service.ReporteService;
import com.taxiuap.backend.communication.dto.ReporteResponse;
import com.taxiuap.backend.communication.enums.SituacionReporte;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;

/** Las rutas de reportes y la foto respetan la regla ADMIN del filtro JWT. */
@SpringBootTest
@AutoConfigureMockMvc
class ReporteAdminControllerSecurityTest {

    @Autowired private MockMvc mockMvc;
    @MockitoBean private ReporteService reporteService;
    @MockitoBean private AlmacenamientoArchivos almacenamientoArchivos;

    private static final ReporteResponse REPORTE = new ReporteResponse(1L, 2L, 3L, "FALLA_ENTREGA", "No respondio",
            SituacionReporte.PENDIENTE, null, null, null, null, null, "foto.jpg", "No respondio", null, "Destino");

    @org.junit.jupiter.api.BeforeEach
    void prepararRespuestas() {
        when(reporteService.obtener(1L)).thenReturn(REPORTE);
        when(almacenamientoArchivos.leer(anyString())).thenReturn(new ByteArrayResource("foto".getBytes()));
    }

    @Test
    void pasajeroNoPuedeListarReportes() throws Exception {
        mockMvc.perform(get("/api/admin/reportes").with(user("pasajero").roles("PASAJERO")))
                .andExpect(status().isForbidden());
    }

    @Test
    void pasajeroNoPuedeDescargarFoto() throws Exception {
        mockMvc.perform(get("/api/admin/reportes/1/foto").with(user("pasajero").roles("PASAJERO")))
                .andExpect(status().isForbidden());
    }

    @Test
    void pasajeroNoPuedeConsultarDetalle() throws Exception {
        mockMvc.perform(get("/api/admin/reportes/1").with(user("pasajero").roles("PASAJERO")))
                .andExpect(status().isForbidden());
    }

    @Test
    void pasajeroNoPuedeResolver() throws Exception {
        mockMvc.perform(put("/api/admin/reportes/1/resolver").with(user("pasajero").roles("PASAJERO"))
                .contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminPuedeLlegarAlEndpointDeReportes() throws Exception {
        mockMvc.perform(get("/api/admin/reportes"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminPuedeConsultarDetalleYDescargarFoto() throws Exception {
        mockMvc.perform(get("/api/admin/reportes/1"))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/admin/reportes/1/foto"))
                .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminPuedeResolverReporte() throws Exception {
        mockMvc.perform(put("/api/admin/reportes/1/resolver")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"tipoResolucion\":\"OTRO\",\"observacionAdmin\":\"Verificado\",\"situacion\":\"RESUELTO\"}"))
                .andExpect(status().isOk());
    }
}
