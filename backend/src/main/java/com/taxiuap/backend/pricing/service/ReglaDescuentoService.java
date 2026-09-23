package com.taxiuap.backend.pricing.service;

import java.time.LocalDate;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.institution.entity.TipoInstitucion;
import com.taxiuap.backend.institution.repository.TipoInstitucionRepository;
import com.taxiuap.backend.pricing.dto.ReglaDescuentoRequest;
import com.taxiuap.backend.pricing.dto.ReglaDescuentoResponse;
import com.taxiuap.backend.pricing.entity.ReglaDescuentoEstudiantil;
import com.taxiuap.backend.pricing.repository.ReglaDescuentoEstudiantilRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;

import lombok.RequiredArgsConstructor;

/**
 * CRUD administrativo de reglas de descuento estudiantil y busqueda de la regla vigente,
 * usada por la regla de negocio 3 (descuento estudiantil).
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ReglaDescuentoService {

    private final ReglaDescuentoEstudiantilRepository reglaDescuentoRepository;
    private final TipoInstitucionRepository tipoInstitucionRepository;
    private final TipoVehiculoRepository tipoVehiculoRepository;

    public List<ReglaDescuentoResponse> listar(boolean incluirInactivos) {
        return reglaDescuentoRepository.findAll().stream()
                .filter(regla -> incluirInactivos || regla.getEstadoReglaDescuento() == EstadoRegistro.A)
                .map(this::aResponse)
                .toList();
    }

    public ReglaDescuentoResponse buscarPorId(Long id) {
        return aResponse(obtenerRegla(id));
    }

    /** Regla ACTIVA cuya vigencia cubre hoy para el tipo de institucion y tipo de vehiculo indicados. */
    public ReglaDescuentoResponse buscarVigente(Integer idTipoInstitucion, Integer idTipoVehiculo) {
        LocalDate hoy = LocalDate.now();
        return reglaDescuentoRepository.findAll().stream()
                .filter(regla -> regla.getEstadoReglaDescuento() == EstadoRegistro.A)
                .filter(regla -> regla.getTipoInstitucion().getId().equals(idTipoInstitucion))
                .filter(regla -> regla.getTipoVehiculo().getId().equals(idTipoVehiculo))
                .filter(regla -> cubreVigencia(regla, hoy))
                .findFirst()
                .map(this::aResponse)
                .orElseThrow(() -> new NegocioException(
                        "No existe una regla de descuento vigente para el tipo de institucion y el tipo de vehiculo indicados"));
    }

    @Transactional
    public ReglaDescuentoResponse crear(ReglaDescuentoRequest request) {
        ReglaDescuentoEstudiantil regla = new ReglaDescuentoEstudiantil();
        regla.setEstadoReglaDescuento(EstadoRegistro.A);
        aplicarDatos(regla, request);
        return aResponse(reglaDescuentoRepository.save(regla));
    }

    @Transactional
    public ReglaDescuentoResponse actualizar(Long id, ReglaDescuentoRequest request) {
        ReglaDescuentoEstudiantil regla = obtenerRegla(id);
        aplicarDatos(regla, request);
        return aResponse(reglaDescuentoRepository.save(regla));
    }

    @Transactional
    public void eliminar(Long id) {
        ReglaDescuentoEstudiantil regla = obtenerRegla(id);
        regla.setEstadoReglaDescuento(EstadoRegistro.X);
        reglaDescuentoRepository.save(regla);
    }

    private void aplicarDatos(ReglaDescuentoEstudiantil regla, ReglaDescuentoRequest request) {
        TipoInstitucion tipoInstitucion = tipoInstitucionRepository.findById(request.idTipoInstitucion())
                .orElseThrow(() -> RecursoNoEncontradoException.de("TipoInstitucion", request.idTipoInstitucion()));
        TipoVehiculo tipoVehiculo = tipoVehiculoRepository.findById(request.idTipoVehiculo())
                .orElseThrow(() -> RecursoNoEncontradoException.de("TipoVehiculo", request.idTipoVehiculo()));

        regla.setTipoInstitucion(tipoInstitucion);
        regla.setTipoVehiculo(tipoVehiculo);
        regla.setPorcentaje(request.porcentaje());
        regla.setMontoMaximo(request.montoMaximo());
        regla.setViajesMaximosDia(request.viajesMaximosDia());
        regla.setVigenteDesde(request.vigenteDesde());
        regla.setVigenteHasta(request.vigenteHasta());
    }

    private boolean cubreVigencia(ReglaDescuentoEstudiantil regla, LocalDate hoy) {
        boolean empezoOnTime = regla.getVigenteDesde() != null && !regla.getVigenteDesde().isAfter(hoy);
        boolean noVencio = regla.getVigenteHasta() == null || !regla.getVigenteHasta().isBefore(hoy);
        return empezoOnTime && noVencio;
    }

    private ReglaDescuentoEstudiantil obtenerRegla(Long id) {
        return reglaDescuentoRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("ReglaDescuentoEstudiantil", id));
    }

    private ReglaDescuentoResponse aResponse(ReglaDescuentoEstudiantil regla) {
        return new ReglaDescuentoResponse(
                regla.getId(),
                regla.getTipoInstitucion().getId(),
                regla.getTipoInstitucion().getNombre(),
                regla.getTipoVehiculo().getId(),
                regla.getTipoVehiculo().getNombre(),
                regla.getPorcentaje(),
                regla.getMontoMaximo(),
                regla.getViajesMaximosDia(),
                regla.getVigenteDesde(),
                regla.getVigenteHasta());
    }
}
