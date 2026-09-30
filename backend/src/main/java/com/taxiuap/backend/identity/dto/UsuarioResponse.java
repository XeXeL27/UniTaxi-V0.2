package com.taxiuap.backend.identity.dto;

import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;

/** Datos publicos de un usuario autenticado. */
public record UsuarioResponse(
        Long idUsuario,
        String nombreUsuario,
        String nombres,
        String apellidos,
        String correo,
        String telefono,
        String rol,
        /** true la primera vez que entra a la app: muestra la guia de inicio. */
        boolean mostrarGuia,
        /** true si entro con Google y todavia no registro su carnet: la app pide la foto del carnet. */
        boolean requiereCarnet) {

    public static UsuarioResponse de(Usuario usuario) {
        Persona persona = usuario.getPersona();
        return new UsuarioResponse(
                usuario.getId(),
                usuario.getNombreUsuario(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getCorreo(),
                persona.getTelefono(),
                usuario.getRol().getCodigo(),
                Boolean.FALSE.equals(usuario.getGuiaVista()),
                Boolean.TRUE.equals(persona.getIngresoGoogle()) && (persona.getCi() == null || persona.getCi().isBlank()));
    }
}
