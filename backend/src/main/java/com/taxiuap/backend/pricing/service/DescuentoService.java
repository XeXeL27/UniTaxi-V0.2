package com.taxiuap.backend.pricing.service;

import java.time.LocalDate;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.pricing.dto.DescuentoRequest;
import com.taxiuap.backend.pricing.dto.DescuentoResponse;
import com.taxiuap.backend.pricing.entity.Descuento;
import com.taxiuap.backend.pricing.repository.DescuentoRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** CRUD administrativo de cupones de descuento y busqueda del cupon vigente por codigo. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class DescuentoService {

    private final DescuentoRepository descuentoRepository;

    public List<DescuentoResponse> listar(boolean incluirInactivos) {
        return descuentoRepository.findAll().stream()
                .filter(descuento -> incluirInactivos || descuento.getEstadoDescuento() == EstadoRegistro.A)
                .map(this::aResponse)
                .toList();
    }

    public DescuentoResponse buscarPorId(Long id) {
        return aResponse(obtenerDescuento(id));
    }

    /** Cupon activo (estado A) cuya vigencia cubre hoy, identificado por su codigo (sin distinguir mayusculas). */
    public DescuentoResponse buscarVigentePorCodigo(String codigo) {
        LocalDate hoy = LocalDate.now();
        return descuentoRepository.findByCodigo(codigo.toUpperCase())
                .filter(descuento -> descuento.getEstadoDescuento() == EstadoRegistro.A)
                .filter(descuento -> cubreVigencia(descuento, hoy))
                .map(this::aResponse)
                .orElseThrow(() -> new NegocioException("El cupon no existe o no esta vigente"));
    }

    @Transactional
    public DescuentoResponse crear(DescuentoRequest request) {
        String codigo = request.codigo().toUpperCase();
        validarCodigoDisponible(codigo, null);
        Descuento descuento = new Descuento();
        descuento.setCodigo(codigo);
        descuento.setEstadoDescuento(EstadoRegistro.A);
        aplicarDatos(descuento, request);
        return aResponse(descuentoRepository.save(descuento));
    }

    @Transactional
    public DescuentoResponse actualizar(Long id, DescuentoRequest request) {
        Descuento descuento = obtenerDescuento(id);
        String codigo = request.codigo().toUpperCase();
        validarCodigoDisponible(codigo, id);
        descuento.setCodigo(codigo);
        aplicarDatos(descuento, request);
        return aResponse(descuentoRepository.save(descuento));
    }

    @Transactional
    public void eliminar(Long id) {
        Descuento descuento = obtenerDescuento(id);
        descuento.setEstadoDescuento(EstadoRegistro.X);
        descuentoRepository.save(descuento);
    }

    private void validarCodigoDisponible(String codigo, Long idActual) {
        descuentoRepository.findByCodigo(codigo)
                .filter(descuento -> !descuento.getId().equals(idActual))
                .ifPresent(descuento -> {
                    throw new NegocioException("Ya existe un descuento con ese codigo");
                });
    }

    private void aplicarDatos(Descuento descuento, DescuentoRequest request) {
        descuento.setDescripcion(request.descripcion());
        descuento.setPorcentaje(request.porcentaje());
        descuento.setMontoMaximo(request.montoMaximo());
        descuento.setUsosMaximos(request.usosMaximos());
        descuento.setVigenteDesde(request.vigenteDesde());
        descuento.setVigenteHasta(request.vigenteHasta());
    }

    private boolean cubreVigencia(Descuento descuento, LocalDate hoy) {
        boolean empezoOnTime = descuento.getVigenteDesde() != null && !descuento.getVigenteDesde().isAfter(hoy);
        boolean noVencio = descuento.getVigenteHasta() == null || !descuento.getVigenteHasta().isBefore(hoy);
        return empezoOnTime && noVencio;
    }

    private Descuento obtenerDescuento(Long id) {
        return descuentoRepository.findById(id)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Descuento", id));
    }

    private DescuentoResponse aResponse(Descuento descuento) {
        return new DescuentoResponse(
                descuento.getId(),
                descuento.getCodigo(),
                descuento.getDescripcion(),
                descuento.getPorcentaje(),
                descuento.getMontoMaximo(),
                descuento.getUsosMaximos(),
                descuento.getVigenteDesde(),
                descuento.getVigenteHasta());
    }
}
