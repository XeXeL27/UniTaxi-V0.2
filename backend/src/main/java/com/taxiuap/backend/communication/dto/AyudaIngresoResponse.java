package com.taxiuap.backend.communication.dto;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

import com.taxiuap.backend.communication.entity.SolicitudAyudaIngreso;
import com.taxiuap.backend.communication.enums.OrigenAyudaIngreso;
import com.taxiuap.backend.communication.enums.ProblemaIngreso;
import com.taxiuap.backend.communication.enums.SituacionAyudaIngreso;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;

/**
 * Mensaje de quien no puede ingresar, para el panel. idUsuario y nombreUsuario son los de su cuenta de
 * la app (pasajero o conductor; comparten credenciales): con idUsuario el panel le reenvia las
 * credenciales. null si la persona ya no tiene cuentas activas de la app. problemas: lo que marco en el
 * login (etiquetas). estadoCuenta: HABILITADA, SUSPENDIDA o SIN_CUENTA (sus cuentas de la app ahora).
 */
public record AyudaIngresoResponse(Long id, LocalDateTime fecha, SituacionAyudaIngreso situacion,
        OrigenAyudaIngreso origen, Long idPersona, String nombreCompleto, String ci, String correo, String telefono,
        String ru, String celular, List<String> problemas, String descripcion, Long idUsuario, String nombreUsuario,
        String estadoCuenta, String motivoSuspension, String observacionAdmin, LocalDateTime fechaAtencion,
        String atendidoPor) {

    public static final String HABILITADA = "HABILITADA";
    public static final String SUSPENDIDA = "SUSPENDIDA";
    public static final String SIN_CUENTA = "SIN_CUENTA";

    public static AyudaIngresoResponse de(SolicitudAyudaIngreso solicitud, Usuario cuenta, String estadoCuenta,
            String motivoSuspension) {
        Persona persona = solicitud.getPersona();
        String ci = persona.getCi() == null ? null
                : persona.getCi() + (persona.getComplementoCi() == null ? "" : "-" + persona.getComplementoCi());
        Usuario admin = solicitud.getUsuarioAdminAtendio();
        return new AyudaIngresoResponse(solicitud.getId(), solicitud.getFecha(), solicitud.getSituacion(),
                solicitud.getOrigen(), persona.getId(), persona.getNombres() + " " + persona.getApellidos(), ci,
                persona.getCorreo(), persona.getTelefono(), solicitud.getRu(), solicitud.getCelular(),
                etiquetas(solicitud.getProblemas()), solicitud.getDescripcion(),
                cuenta == null ? null : cuenta.getId(), cuenta == null ? null : cuenta.getNombreUsuario(),
                estadoCuenta, motivoSuspension, solicitud.getObservacionAdmin(), solicitud.getFechaAtencion(),
                admin == null ? null : admin.getNombreUsuario());
    }

    private static List<String> etiquetas(String codigos) {
        if (codigos == null || codigos.isBlank()) return List.of();
        return Arrays.stream(codigos.split(","))
                .map(String::trim)
                .map(c -> Arrays.stream(ProblemaIngreso.values()).filter(p -> p.name().equals(c)).findFirst()
                        .map(ProblemaIngreso::getEtiqueta).orElse(c))
                .toList();
    }
}
