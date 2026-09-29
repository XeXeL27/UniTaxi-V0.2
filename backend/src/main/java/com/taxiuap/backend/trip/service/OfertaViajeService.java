package com.taxiuap.backend.trip.service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.dto.OfertaViajeRequest;
import com.taxiuap.backend.trip.dto.OfertaViajeResponse;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.entity.OfertaViaje;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.SituacionOferta;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.repository.OfertaViajeRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;
import com.taxiuap.backend.vehicle.service.DocumentoConductorService;

import lombok.RequiredArgsConstructor;

/**
 * Ofertas de los conductores sobre las solicitudes de viaje, y aceptacion atomica de una oferta
 * por parte del pasajero (regla de negocio 5).
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class OfertaViajeService {

    private final OfertaViajeRepository ofertaViajeRepository;
    private final SolicitudViajeRepository solicitudViajeRepository;
    private final ConductorRepository conductorRepository;
    private final PasajeroRepository pasajeroRepository;
    private final VehiculoRepository vehiculoRepository;
    private final DocumentoConductorService documentoConductorService;
    private final ViajeService viajeService;
    private final ViajeEventPublisher viajeEventPublisher;

    @Transactional
    public OfertaViajeResponse ofertar(Long idSolicitud, OfertaViajeRequest request) {
        Conductor conductor = buscarConductor();
        // Reglas de negocio 1 y 2, misma puerta que para listar solicitudes disponibles.
        if (!documentoConductorService.puedeOperar(conductor.getId())) {
            throw new NegocioException("El conductor no esta habilitado para recibir solicitudes");
        }

        SolicitudViaje solicitud = solicitudViajeRepository.findById(idSolicitud)
                .orElseThrow(() -> RecursoNoEncontradoException.de("SolicitudViaje", idSolicitud));
        if (solicitud.getSituacionSolicitud() != SituacionSolicitud.PENDIENTE
                && solicitud.getSituacionSolicitud() != SituacionSolicitud.CON_OFERTAS) {
            throw new NegocioException("La solicitud ya no admite ofertas");
        }
        if (ofertaViajeRepository.existsBySolicitudIdAndConductorId(idSolicitud, conductor.getId())) {
            throw new NegocioException("Ya oferto en esta solicitud");
        }

        OfertaViaje oferta = new OfertaViaje();
        oferta.setSolicitud(solicitud);
        oferta.setConductor(conductor);
        oferta.setPrecioOfertado(request.precioOfertado());
        oferta.setTiempoLlegadaMin(request.tiempoLlegadaMin());
        oferta.setSituacionOferta(SituacionOferta.PENDIENTE);
        oferta.setFechaOferta(LocalDateTime.now());
        oferta.setEstadoOferViaje(EstadoRegistro.A);
        OfertaViaje guardada = ofertaViajeRepository.save(oferta);

        if (solicitud.getSituacionSolicitud() == SituacionSolicitud.PENDIENTE) {
            solicitud.setSituacionSolicitud(SituacionSolicitud.CON_OFERTAS);
            solicitudViajeRepository.save(solicitud);
        }

        OfertaViajeResponse respuesta = aResponse(guardada);
        if (solicitud.getPasajero() != null && solicitud.getPasajero().getUsuario() != null) {
            viajeEventPublisher.publicarOfertaNueva(solicitud.getPasajero().getUsuario().getId(), respuesta);
        }
        return respuesta;
    }

    public List<OfertaViajeResponse> listarDeSolicitud(Long idSolicitud) {
        Pasajero pasajero = buscarPasajero();
        SolicitudViaje solicitud = solicitudViajeRepository.findById(idSolicitud)
                .orElseThrow(() -> RecursoNoEncontradoException.de("SolicitudViaje", idSolicitud));
        if (solicitud.getPasajero() == null || !solicitud.getPasajero().getId().equals(pasajero.getId())) {
            throw RecursoNoEncontradoException.de("SolicitudViaje", idSolicitud);
        }
        return ofertaViajeRepository.findBySolicitudIdAndSituacionOferta(idSolicitud, SituacionOferta.PENDIENTE)
                .stream()
                .map(this::aResponse)
                .toList();
    }

    public List<OfertaViajeResponse> listarPropias() {
        Conductor conductor = buscarConductor();
        return ofertaViajeRepository.findByConductorId(conductor.getId()).stream()
                .map(this::aResponse)
                .toList();
    }

    /**
     * Aceptar una oferta (regla de negocio 5). El cambio de situacion de la solicitud se hace con
     * un UPDATE condicional (SolicitudViajeRepository.aceptarSiDisponible), nunca con un
     * leer-y-escribir en Java: la fila la serializa PostgreSQL, asi que si dos pasajeros (o dos
     * peticiones del mismo pasajero) intentan aceptar dos ofertas de la misma solicitud casi al
     * mismo tiempo, solo una gana el UPDATE (1 fila afectada) y la otra pierde (0 filas). Solo
     * cuando el UPDATE confirma que esta solicitud era la que se acepto se marca la oferta como
     * ACEPTADA, se rechazan las demas y se crea el viaje; todo dentro de la misma transaccion, de
     * modo que si crearDesdeOferta falla se deshace tambien la aceptacion.
     */
    @Transactional
    public ViajeResponse aceptar(Long idOferta) {
        OfertaViaje ofertaSolicitada = ofertaViajeRepository.findById(idOferta)
                .orElseThrow(() -> RecursoNoEncontradoException.de("OfertaViaje", idOferta));
        if (ofertaSolicitada.getSituacionOferta() != SituacionOferta.PENDIENTE) {
            throw new NegocioException("La oferta ya no esta pendiente");
        }

        SolicitudViaje solicitudSolicitada = ofertaSolicitada.getSolicitud();
        Pasajero pasajero = buscarPasajero();
        if (solicitudSolicitada.getPasajero() == null
                || !solicitudSolicitada.getPasajero().getId().equals(pasajero.getId())) {
            throw RecursoNoEncontradoException.de("SolicitudViaje", solicitudSolicitada.getId());
        }
        Long idSolicitud = solicitudSolicitada.getId();

        int filasAfectadas = solicitudViajeRepository.aceptarSiDisponible(idSolicitud);
        if (filasAfectadas == 0) {
            throw new ConflictoException("La solicitud ya no esta disponible");
        }

        // El UPDATE anterior limpia el contexto de persistencia (clearAutomatically): se vuelve a
        // leer todo desde la base para no trabajar con entidades desactualizadas o desasociadas.
        SolicitudViaje solicitud = solicitudViajeRepository.findById(idSolicitud)
                .orElseThrow(() -> RecursoNoEncontradoException.de("SolicitudViaje", idSolicitud));
        OfertaViaje oferta = ofertaViajeRepository.findById(idOferta)
                .orElseThrow(() -> RecursoNoEncontradoException.de("OfertaViaje", idOferta));

        oferta.setSituacionOferta(SituacionOferta.ACEPTADA);
        ofertaViajeRepository.save(oferta);

        List<OfertaViaje> otrasOfertas = ofertaViajeRepository
                .findBySolicitudIdAndSituacionOferta(idSolicitud, SituacionOferta.PENDIENTE);
        otrasOfertas.forEach(otra -> otra.setSituacionOferta(SituacionOferta.RECHAZADA));
        ofertaViajeRepository.saveAll(otrasOfertas);

        Viaje viaje = viajeService.crearDesdeOferta(solicitud, oferta);

        viajeEventPublisher.publicarSolicitudCerrada(idSolicitud, "Solicitud aceptada");

        return viajeService.obtenerPorId(viaje.getId());
    }

    /**
     * El conductor toma una solicitud directamente (estilo Uber) al precio de la solicitud, que
     * con precio fijo es el de la plataforma. Usa el mismo UPDATE condicional de la regla 5 que
     * aceptar(): si dos conductores tocan "Aceptar" a la vez, solo uno gana la fila y el otro
     * recibe 409. La oferta queda registrada ya ACEPTADA para conservar el rastro del modelo de
     * datos (solicitud -> oferta -> viaje), y las ofertas pendientes de otros se rechazan.
     */
    @Transactional
    public ViajeResponse aceptarDirecto(Long idSolicitud) {
        Conductor conductor = buscarConductor();
        // Reglas de negocio 1 y 2.
        if (!documentoConductorService.puedeOperar(conductor.getId())) {
            throw new NegocioException("El conductor no esta habilitado para recibir solicitudes");
        }
        if (viajeService.conductorTieneViajeActivo(conductor.getId())) {
            throw new NegocioException("Ya tiene un viaje en curso");
        }
        if (!solicitudViajeRepository.existsById(idSolicitud)) {
            throw RecursoNoEncontradoException.de("SolicitudViaje", idSolicitud);
        }
        Long idConductor = conductor.getId();
        // El conductor que cancelo este pedido no lo puede volver a tomar: queda para otro.
        if (ofertaViajeRepository.existsBySolicitudIdAndConductorIdAndSituacionOferta(
                idSolicitud, idConductor, SituacionOferta.RECHAZADA)) {
            throw new ConflictoException("Cancelaste este viaje: lo tomara otro conductor");
        }

        int filasAfectadas = solicitudViajeRepository.aceptarSiDisponible(idSolicitud);
        if (filasAfectadas == 0) {
            throw new ConflictoException("Otro conductor ya tomo esta solicitud o fue cancelada");
        }

        // El UPDATE limpia el contexto de persistencia: se vuelve a leer desde la base.
        SolicitudViaje solicitud = solicitudViajeRepository.findById(idSolicitud)
                .orElseThrow(() -> RecursoNoEncontradoException.de("SolicitudViaje", idSolicitud));
        Conductor conductorActual = conductorRepository.findById(idConductor)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Conductor", idConductor));

        OfertaViaje oferta = new OfertaViaje();
        oferta.setSolicitud(solicitud);
        oferta.setConductor(conductorActual);
        oferta.setPrecioOfertado(solicitud.getPrecioSugerido());
        oferta.setSituacionOferta(SituacionOferta.ACEPTADA);
        oferta.setFechaOferta(LocalDateTime.now());
        oferta.setEstadoOferViaje(EstadoRegistro.A);
        ofertaViajeRepository.save(oferta);

        List<OfertaViaje> otrasOfertas = ofertaViajeRepository
                .findBySolicitudIdAndSituacionOferta(idSolicitud, SituacionOferta.PENDIENTE);
        otrasOfertas.forEach(otra -> otra.setSituacionOferta(SituacionOferta.RECHAZADA));
        ofertaViajeRepository.saveAll(otrasOfertas);

        Viaje viaje = viajeService.crearDesdeOferta(solicitud, oferta);

        viajeEventPublisher.publicarSolicitudCerrada(idSolicitud, "Solicitud aceptada");

        return viajeService.obtenerPorId(viaje.getId());
    }

    private Pasajero buscarPasajero() {
        return pasajeroRepository.findByUsuarioId(UsuarioActual.idUsuario())
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de pasajero"));
    }

    private Conductor buscarConductor() {
        return conductorRepository.findByUsuarioId(UsuarioActual.idUsuario())
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
    }

    private String buscarPlacaVehiculo(Long idConductor) {
        return vehiculoRepository.findByConductorId(idConductor).stream()
                .filter(vehiculo -> vehiculo.getEstadoVehiculo() == EstadoRegistro.A)
                .map(Vehiculo::getPlaca)
                .findFirst()
                .orElse(null);
    }

    private OfertaViajeResponse aResponse(OfertaViaje oferta) {
        Conductor conductor = oferta.getConductor();
        String nombreConductor = conductor != null && conductor.getUsuario() != null
                && conductor.getUsuario().getPersona() != null
                        ? conductor.getUsuario().getPersona().getNombres() + " "
                                + conductor.getUsuario().getPersona().getApellidos()
                        : null;

        return new OfertaViajeResponse(
                oferta.getId(),
                oferta.getSolicitud() != null ? oferta.getSolicitud().getId() : null,
                conductor != null ? conductor.getId() : null,
                nombreConductor,
                conductor != null ? conductor.getCalificacionPromedio() : null,
                conductor != null ? buscarPlacaVehiculo(conductor.getId()) : null,
                oferta.getPrecioOfertado(),
                oferta.getTiempoLlegadaMin(),
                oferta.getSituacionOferta(),
                oferta.getFechaOferta());
    }
}
