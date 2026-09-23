package com.taxiuap.backend.pricing.service;

import java.time.LocalDate;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.location.entity.Zona;
import com.taxiuap.backend.location.repository.ZonaRepository;
import com.taxiuap.backend.pricing.dto.TarifaRequest;
import com.taxiuap.backend.pricing.dto.TarifaResponse;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.repository.TarifaRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;

import lombok.RequiredArgsConstructor;

/** CRUD administrativo de tarifas y busqueda de la tarifa vigente para el calculo del viaje. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TarifaService {

    private final TarifaRepository tarifaRepository;
    private final CategoriaServicioRepository categoriaServicioRepository;
    private final ZonaRepository zonaRepository;

    public List<TarifaResponse> listar(Integer idZona, Integer idCategoriaServicio, boolean incluirInactivos) {
        return tarifaRepository.findAll().stream()
                .filter(tarifa -> incluirInactivos || tarifa.getEstadoTarifa() == EstadoRegistro.A)
                .filter(tarifa -> idZona == null || tarifa.getZona().getId().equals(idZona))
                .filter(tarifa -> idCategoriaServicio == null
                        || tarifa.getCategoriaServicio().getId().equals(idCategoriaServicio))
                .map(this::aResponse)
                .toList();
    }

    public TarifaResponse buscarPorId(Long id) {
        return aResponse(obtenerTarifa(id));
    }

    /** Tarifa ACTIVA cuya vigencia cubre hoy, usada por el calculo de precio del viaje. */
    public TarifaResponse buscarVigente(Integer idCategoriaServicio, Integer idZona) {
        LocalDate hoy = LocalDate.now();
        return tarifaRepository.findByCategoriaServicioIdAndZonaId(idCategoriaServicio, idZona).stream()
                .filter(tarifa -> tarifa.getEstadoTarifa() == EstadoRegistro.A)
                .filter(tarifa -> cubreVigencia(tarifa, hoy))
                .findFirst()
                .map(this::aResponse)
                .orElseThrow(() -> new NegocioException(
                        "No existe una tarifa vigente para la categoria de servicio y zona indicadas"));
    }

    @Transactional
    public TarifaResponse crear(TarifaRequest request) {
        Tarifa tarifa = new Tarifa();
        tarifa.setEstadoTarifa(EstadoRegistro.A);
        aplicarDatos(tarifa, request);
        return aResponse(tarifaRepository.save(tarifa));
    }

    @Transactional
    public TarifaResponse actualizar(Long id, TarifaRequest request) {
        Tarifa tarifa = obtenerTarifa(id);
        aplicarDatos(tarifa, request);
        return aResponse(tarifaRepository.save(tarifa));
    }

    @Transactional
    public void eliminar(Long id) {
        Tarifa tarifa = obtenerTarifa(id);
        tarifa.setEstadoTarifa(EstadoRegistro.X);
        tarifaRepository.save(tarifa);
    }

    private void aplicarDatos(Tarifa tarifa, TarifaRequest request) {
        if (request.vigenteHasta() != null && !request.vigenteHasta().isAfter(request.vigenteDesde())) {
            throw new NegocioException("La vigencia final debe ser posterior a la inicial");
        }
        CategoriaServicio categoriaServicio = categoriaServicioRepository.findById(request.idCategoriaServicio())
                .orElseThrow(() -> RecursoNoEncontradoException.de("CategoriaServicio", request.idCategoriaServicio()));
        Zona zona = zonaRepository.findById(request.idZona())
                .orElseThrow(() -> RecursoNoEncontradoException.de("Zona", request.idZona()));

        tarifa.setCategoriaServicio(categoriaServicio);
        tarifa.setZona(zona);
        tarifa.setTarifaBase(request.tarifaBase());
        tarifa.setPrecioKm(request.precioKm());
        tarifa.setPrecioMinuto(request.precioMinuto());
        tarifa.setTarifaMinima(request.tarifaMinima());
        tarifa.setVigenteDesde(request.vigenteDesde());
        tarifa.setVigenteHasta(request.vigenteHasta());
    }

    private boolean cubreVigencia(Tarifa tarifa, LocalDate hoy) {
        boolean empezoOnTime = tarifa.getVigenteDesde() != null && !tarifa.getVigenteDesde().isAfter(hoy);
        boolean noVencio = tarifa.getVigenteHasta() == null || !tarifa.getVigenteHasta().isBefore(hoy);
        return empezoOnTime && noVencio;
    }

    private Tarifa obtenerTarifa(Long id) {
        return tarifaRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Tarifa", id));
    }

    private TarifaResponse aResponse(Tarifa tarifa) {
        return new TarifaResponse(
                tarifa.getId(),
                tarifa.getCategoriaServicio().getId(),
                tarifa.getCategoriaServicio().getNombre(),
                tarifa.getZona().getId(),
                tarifa.getZona().getNombre(),
                tarifa.getTarifaBase(),
                tarifa.getPrecioKm(),
                tarifa.getPrecioMinuto(),
                tarifa.getTarifaMinima(),
                tarifa.getVigenteDesde(),
                tarifa.getVigenteHasta());
    }
}
