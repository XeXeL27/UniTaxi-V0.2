package com.taxiuap.backend.identity.dto;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Persona cuyo carnet espera la revision del administrador (OBSERVADO): los datos que leyo el
 * sistema (IA u otro lector) o que escribio la persona, para compararlos con las fotos. idUsuario
 * sirve para pedir las fotos del carnet (/api/admin/usuarios/{id}/carnet/...) e idConductor las de la
 * licencia, si es conductor.
 */
public record CarnetObservadoResponse(
        Long idPersona,
        Long idUsuario,
        Long idConductor,
        String nombres,
        String apellidos,
        String ci,
        String complementoCi,
        LocalDate fechaNacimiento,
        String correo,
        String telefono,
        /** "Pasajero", "Conductor" o "Pasajero y conductor". */
        String cuentas,
        String numeroLicencia,
        String motivo,
        LocalDateTime fechaObservacion,
        /** RU si se registro como estudiante UAP: el admin lo aprueba como estudiante o como pasajero normal. */
        String ruEstudiante) {
}
