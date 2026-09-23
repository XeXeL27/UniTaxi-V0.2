package com.taxiuap.backend.seed;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.stereotype.Component;

import com.taxiuap.backend.communication.entity.AlertaSos;
import com.taxiuap.backend.communication.entity.Mensaje;
import com.taxiuap.backend.communication.entity.Reporte;
import com.taxiuap.backend.communication.enums.SituacionAlerta;
import com.taxiuap.backend.communication.enums.SituacionReporte;
import com.taxiuap.backend.communication.repository.AlertaSosRepository;
import com.taxiuap.backend.communication.repository.MensajeRepository;
import com.taxiuap.backend.communication.repository.ReporteRepository;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.rating.entity.Calificacion;
import com.taxiuap.backend.rating.entity.CalificacionEtiqueta;
import com.taxiuap.backend.rating.entity.EtiquetaCalificacion;
import com.taxiuap.backend.rating.entity.RespuestaCalificacion;
import com.taxiuap.backend.rating.enums.AplicaA;
import com.taxiuap.backend.rating.enums.TipoCalificacion;
import com.taxiuap.backend.rating.repository.CalificacionEtiquetaRepository;
import com.taxiuap.backend.rating.repository.CalificacionRepository;
import com.taxiuap.backend.rating.repository.RespuestaCalificacionRepository;
import com.taxiuap.backend.seed.SeedCatalogos.CatalogosSembrados;
import com.taxiuap.backend.seed.SeedViajes.ViajesSembrados;
import com.taxiuap.backend.trip.entity.Viaje;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Siembra las calificaciones (con algunas etiquetas y una respuesta), los mensajes de chat, la
 * alerta SOS y el reporte de incidente de prueba.
 */
@Component
@RequiredArgsConstructor
@Slf4j
class SeedComunicacion {

    private final CalificacionRepository calificacionRepository;
    private final CalificacionEtiquetaRepository calificacionEtiquetaRepository;
    private final RespuestaCalificacionRepository respuestaCalificacionRepository;
    private final MensajeRepository mensajeRepository;
    private final AlertaSosRepository alertaSosRepository;
    private final ReporteRepository reporteRepository;

    void sembrar(CatalogosSembrados catalogos, ViajesSembrados viajes) {
        log.info("Sembrando calificaciones...");

        List<Viaje> viajesCalificados = viajes.completados().subList(0, 4);
        EtiquetaCalificacion etiquetaPositivaConductor = buscarEtiqueta(catalogos, AplicaA.CONDUCTOR, true);
        EtiquetaCalificacion etiquetaPositivaPasajero = buscarEtiqueta(catalogos, AplicaA.PASAJERO, true);

        Calificacion primeraCalifPasajeroAConductor = null;
        int indice = 0;
        for (Viaje viaje : viajesCalificados) {
            Calificacion califPasajeroAConductor = crearCalificacion(viaje,
                    viaje.getPasajero().getUsuario(), viaje.getConductor().getUsuario(),
                    TipoCalificacion.PASAJERO_A_CONDUCTOR, 5, "Muy buen viaje, conductor amable y puntual.");
            Calificacion califConductorAPasajero = crearCalificacion(viaje,
                    viaje.getConductor().getUsuario(), viaje.getPasajero().getUsuario(),
                    TipoCalificacion.CONDUCTOR_A_PASAJERO, 5, "Pasajero puntual y respetuoso.");

            if (indice == 0) {
                crearCalificacionEtiqueta(califPasajeroAConductor, etiquetaPositivaConductor);
                primeraCalifPasajeroAConductor = califPasajeroAConductor;
            }
            if (indice == 1) {
                crearCalificacionEtiqueta(califConductorAPasajero, etiquetaPositivaPasajero);
            }
            indice++;
        }

        if (primeraCalifPasajeroAConductor != null) {
            crearRespuestaCalificacion(primeraCalifPasajeroAConductor);
        }

        log.info("Sembrando mensajes de chat...");
        crearMensajesChat(viajesCalificados.get(0));
        crearMensajesChat(viajes.viajeEnCurso());

        log.info("Sembrando alerta SOS y reporte de incidente...");
        crearAlertaSos(viajes.viajeEnCurso());
        crearReporte(viajesCalificados.get(1));

        log.info("Comunicacion sembrada: {} calificaciones, mensajes en 2 viajes, 1 alerta SOS atendida, "
                + "1 reporte resuelto", viajesCalificados.size() * 2);
    }

    private EtiquetaCalificacion buscarEtiqueta(CatalogosSembrados catalogos, AplicaA aplicaA, boolean positiva) {
        return catalogos.etiquetas().stream()
                .filter(etiqueta -> etiqueta.getAplicaA() == aplicaA)
                .filter(etiqueta -> positiva == (etiqueta.getTipo() == com.taxiuap.backend.rating.enums.TipoEtiqueta.POSITIVA))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("No se encontro etiqueta de calificacion sembrada"));
    }

    private Calificacion crearCalificacion(Viaje viaje, Usuario emisor, Usuario receptor, TipoCalificacion tipo,
            int puntuacion, String comentario) {
        Calificacion calificacion = new Calificacion();
        calificacion.setViaje(viaje);
        calificacion.setUsuarioEmisor(emisor);
        calificacion.setUsuarioReceptor(receptor);
        calificacion.setTipo(tipo);
        calificacion.setPuntuacion(puntuacion);
        calificacion.setComentario(comentario);
        calificacion.setFecha(viaje.getFechaFin().plusMinutes(10));
        return calificacionRepository.save(calificacion);
    }

    private void crearCalificacionEtiqueta(Calificacion calificacion, EtiquetaCalificacion etiqueta) {
        CalificacionEtiqueta calificacionEtiqueta = new CalificacionEtiqueta();
        calificacionEtiqueta.setCalificacion(calificacion);
        calificacionEtiqueta.setEtiquetaCalificacion(etiqueta);
        calificacionEtiquetaRepository.save(calificacionEtiqueta);
    }

    private void crearRespuestaCalificacion(Calificacion calificacion) {
        RespuestaCalificacion respuesta = new RespuestaCalificacion();
        respuesta.setCalificacion(calificacion);
        respuesta.setConductor(calificacion.getViaje().getConductor());
        respuesta.setTexto("Gracias por tu comentario, fue un gusto llevarte.");
        respuesta.setFecha(calificacion.getFecha().plusHours(1));
        respuestaCalificacionRepository.save(respuesta);
    }

    private void crearMensajesChat(Viaje viaje) {
        LocalDateTime base = viaje.getFechaInicio() != null ? viaje.getFechaInicio() : LocalDateTime.now().minusMinutes(20);
        crearMensaje(viaje, viaje.getPasajero().getUsuario(), "Hola, ya estoy esperando en la puerta.", base);
        crearMensaje(viaje, viaje.getConductor().getUsuario(), "Voy en camino, llego en unos minutos.", base.plusMinutes(1));
        crearMensaje(viaje, viaje.getConductor().getUsuario(), "Ya llegue, te espero afuera.", base.plusMinutes(6));
    }

    private void crearMensaje(Viaje viaje, Usuario emisor, String contenido, LocalDateTime fecha) {
        Mensaje mensaje = new Mensaje();
        mensaje.setViaje(viaje);
        mensaje.setUsuarioEmisor(emisor);
        mensaje.setContenido(contenido);
        mensaje.setLeido(true);
        mensaje.setFecha(fecha);
        mensajeRepository.save(mensaje);
    }

    private void crearAlertaSos(Viaje viaje) {
        AlertaSos alerta = new AlertaSos();
        alerta.setViaje(viaje);
        alerta.setUsuario(viaje.getPasajero().getUsuario());
        alerta.setUbicacion(viaje.getOrigen());
        alerta.setSituacionAlerta(SituacionAlerta.ATENDIDA);
        alerta.setFecha(LocalDateTime.now().minusMinutes(8));
        alertaSosRepository.save(alerta);
    }

    private void crearReporte(Viaje viaje) {
        Reporte reporte = new Reporte();
        reporte.setViaje(viaje);
        reporte.setUsuarioReporta(viaje.getPasajero().getUsuario());
        reporte.setMotivo("Ruta distinta a la esperada");
        reporte.setDescripcion("El conductor tomo una ruta mas larga que la sugerida por la aplicacion.");
        reporte.setSituacionReporte(SituacionReporte.RESUELTO);
        reporte.setFecha(viaje.getFechaFin().plusMinutes(30));
        reporteRepository.save(reporte);
    }
}
