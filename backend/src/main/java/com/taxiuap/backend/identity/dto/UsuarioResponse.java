package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;

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
        boolean requiereCarnet,
        /** true si se le enviaron sus credenciales por correo y todavia no vio el aviso en la app. */
        boolean avisoCredenciales,
        /**
         * true si sus datos del carnet esperan la revision de un administrador (OBSERVADO): la app
         * muestra el aviso de revision en vez de la pantalla principal.
         */
        boolean carnetObservado,
        /**
         * Lo que le falta del carnet a una cuenta que ya usaba la app: SELFIE (solo la foto con el carnet),
         * CARNET (las fotos del carnet y la foto con el carnet) o VENCIDO (su carnet vencio: fotos del carnet
         * nuevo y la foto con el carnet; mientras tanto no pide viajes ni recibe solicitudes). null = nada.
         */
        String carnetPendiente,
        /** Hasta cuando puede subir la foto con el carnet antes de que su cuenta se suspenda (null = sin plazo). */
        LocalDateTime plazoSelfie,
        /** "Valida hasta" de su carnet, si se leyo. */
        LocalDate carnetVencimiento) {

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
                Boolean.TRUE.equals(persona.getIngresoGoogle()) && (persona.getCi() == null || persona.getCi().isBlank()),
                Boolean.TRUE.equals(usuario.getAvisoCredenciales()),
                persona.carnetObservado(),
                carnetPendiente(persona),
                persona.getPlazoSelfieCarnet(),
                persona.getCarnetVencimiento());
    }

    static String carnetPendiente(Persona persona) {
        if (persona.getCi() == null || persona.getCi().isBlank()) {
            return null;
        }
        if (persona.getCarnetVencimiento() != null && persona.getCarnetVencimiento().isBefore(LocalDate.now())) {
            return "VENCIDO";
        }
        if (persona.getCarnetSelfieUrl() != null) {
            return null;
        }
        return persona.getCarnetAnversoUrl() != null && persona.getCarnetReversoUrl() != null ? "SELFIE" : "CARNET";
    }
}
