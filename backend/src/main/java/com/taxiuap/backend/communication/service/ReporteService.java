package com.taxiuap.backend.communication.service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.dto.ReporteResponse;
import com.taxiuap.backend.communication.dto.ResolverReporteRequest;
import com.taxiuap.backend.communication.entity.Reporte;
import com.taxiuap.backend.communication.repository.ReporteRepository;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** Consulta y resolución administrativa de incidentes DELIVERY. No realiza movimientos de dinero. */
@Service
@RequiredArgsConstructor
public class ReporteService {

    private final ReporteRepository reporteRepository;
    private final UsuarioRepository usuarioRepository;

    @Transactional(readOnly = true)
    public List<ReporteResponse> listar() {
        return reporteRepository.findAll().stream().map(ReporteResponse::de).toList();
    }

    @Transactional(readOnly = true)
    public ReporteResponse obtener(Long id) {
        return ReporteResponse.de(buscar(id));
    }

    @Transactional
    public ReporteResponse resolver(Long id, ResolverReporteRequest request, JwtUser admin) {
        Reporte reporte = buscar(id);
        Usuario usuario = usuarioRepository.findById(admin.idUsuario())
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", admin.idUsuario()));
        reporte.setTipoResolucion(request.tipoResolucion());
        reporte.setObservacionAdmin(request.observacionAdmin());
        reporte.setSituacionReporte(request.situacion());
        reporte.setFechaResolucion(LocalDateTime.now());
        reporte.setUsuarioAdminResolvio(usuario);
        return ReporteResponse.de(reporteRepository.save(reporte));
    }

    private Reporte buscar(Long id) {
        return reporteRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Reporte", id));
    }
}
