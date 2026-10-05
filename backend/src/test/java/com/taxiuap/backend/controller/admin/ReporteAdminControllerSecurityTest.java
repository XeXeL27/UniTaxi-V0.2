package com.taxiuap.backend.controller.admin;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import com.taxiuap.backend.communication.service.ReporteService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;

/** Las rutas de reportes y la foto respetan la regla ADMIN del filtro JWT. */
@SpringBootTest
@AutoConfigureMockMvc
class ReporteAdminControllerSecurityTest {

    @Autowired private MockMvc mockMvc;
    @MockitoBean private ReporteService reporteService;
    @MockitoBean private AlmacenamientoArchivos almacenamientoArchivos;

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
    @WithMockUser(roles = "ADMIN")
    void adminPuedeLlegarAlEndpointDeReportes() throws Exception {
        mockMvc.perform(get("/api/admin/reportes"))
                .andExpect(status().isOk());
    }
}
