package com.taxiuap.backend.communication.dto;

import java.time.LocalDateTime;

import com.taxiuap.backend.communication.entity.SolicitudAyudaIngreso;
import com.taxiuap.backend.communication.enums.OrigenAyudaIngreso;
import com.taxiuap.backend.communication.enums.SituacionAyudaIngreso;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;

/**
 * Mensaje de quien no puede ingresar, para el panel. idUsuario y nombreUsuario son los de su cuenta de
 * la app (pasajero o conductor; comparten credenciales): con idUsuario el panel le reenvia las
 * credenciales. null si la persona ya no tiene cuentas activas de la app.
 */
public record AyudaIngresoResponse(Long id, LocalDateTime fecha, SituacionAyudaIngreso situacion,
        OrigenAyudaIngreso origen, Long idPersona, String nombreCompleto, String ci, String correo, String ru,
        String celular, String descripcion, Long idUsuario, String nombreUsuario, String observacionAdmin,
        LocalDateTime fechaAtencion, String atendidoPor) {

    public static AyudaIngresoResponse de(SolicitudAyudaIngreso solicitud, Usuario cuenta) {
        Persona persona = solicitud.getPersona();
        String ci = persona.getCi() == null ? null
                : persona.getCi() + (persona.getComplementoCi() == null ? "" : "-" + persona.getComplementoCi());
        Usuario admin = solicitud.getUsuarioAdminAtendio();
        return new AyudaIngresoResponse(solicitud.getId(), solicitud.getFecha(), solicitud.getSituacion(),
                solicitud.getOrigen(), persona.getId(), persona.getNombres() + " " + persona.getApellidos(), ci,
                persona.getCorreo(), solicitud.getRu(), solicitud.getCelular(), solicitud.getDescripcion(),
                cuenta == null ? null : cuenta.getId(), cuenta == null ? null : cuenta.getNombreUsuario(),
                solicitud.getObservacionAdmin(), solicitud.getFechaAtencion(),
                admin == null ? null : admin.getNombreUsuario());
    }
}
