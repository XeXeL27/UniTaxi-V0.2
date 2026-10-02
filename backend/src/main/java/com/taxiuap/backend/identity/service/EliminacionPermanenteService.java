package com.taxiuap.backend.identity.service;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Locale;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.SecuenciasInitializer;
import com.taxiuap.backend.identity.dto.PersonaEliminableResponse;
import com.taxiuap.backend.identity.dto.ResumenEliminacionResponse;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/**
 * Personas > Eliminacion permanente (pedido del usuario, 2026-10-02; excepcion a la regla 11 de
 * borrado logico). Borra de la BD, sin vuelta atras, la persona, sus cuentas (con sus credenciales)
 * y todo lo que es solo suyo: dispositivos, notificaciones, favoritos, contactos, moto, documentos,
 * QR, permisos, billetera, ubicacion, datos de estudiante, solicitudes sin viaje, ofertas, mensajes,
 * reportes y alertas; y su carpeta de archivos.
 *
 * Los viajes que hizo con otra persona y sus calificaciones NO se borran: son tambien del otro (su
 * historial y su promedio). Pasan al registro fijo "USUARIO ELIMINADO" (persona, usuario, pasajero y
 * conductor con id 0, en X: no aparece en listados ni puede ingresar). Su moto queda solo si esos
 * viajes la usan. Al terminar las secuencias vuelven al ultimo id (el siguiente registro es el correlativo).
 */
@Service
@RequiredArgsConstructor
@Transactional
public class EliminacionPermanenteService {

    /** Id fijo del registro "USUARIO ELIMINADO" en persona, usuario, pasajero y conductor. */
    public static final long ID_ELIMINADO = 0L;

    private final NamedParameterJdbcTemplate jdbc;
    private final PersonaRepository personaRepository;
    private final AlmacenamientoArchivos almacenamientoArchivos;
    private final SecuenciasInitializer secuenciasInitializer;

    @Transactional(readOnly = true)
    public List<PersonaEliminableResponse> listar() {
        return jdbc.query("""
                select p.id_persona, p.nombres, p.apellidos, p.ci, p.complemento_ci, p.correo, p.telefono,
                       p.estado_persona, p.creado_en,
                       (select string_agg(distinct r.codigo, ', ') from usuario u join rol r on r.id_rol = u.id_rol
                         where u.id_persona = p.id_persona) as cuentas
                from persona p where p.id_persona > 0 order by p.id_persona""",
                new MapSqlParameterSource(),
                (rs, i) -> new PersonaEliminableResponse(
                        rs.getLong("id_persona"),
                        rs.getString("nombres"),
                        rs.getString("apellidos"),
                        conComplemento(rs.getString("ci"), rs.getString("complemento_ci")),
                        rs.getString("correo"),
                        rs.getString("telefono"),
                        rs.getString("cuentas") == null ? "" : rs.getString("cuentas"),
                        "A".equals(rs.getString("estado_persona")) ? "ACTIVA" : "ELIMINADA",
                        rs.getTimestamp("creado_en") == null ? null : rs.getTimestamp("creado_en").toLocalDateTime()));
    }

    @Transactional(readOnly = true)
    public ResumenEliminacionResponse resumen(Long idPersona, Long idUsuarioActual) {
        Persona persona = buscar(idPersona);
        Ids ids = ids(idPersona);
        List<ResumenEliminacionResponse.Elemento> elementos = new ArrayList<>();
        agregar(elementos, "Cuentas de usuario (y sus credenciales)", ids.usuarios.size());
        agregar(elementos, "Solicitudes de viaje sin viaje", contar("""
                select count(*) from solicitud_viaje s where s.id_pasajero in (:pasajeros)
                and not exists (select 1 from viaje v where v.id_sol_viaje = s.id_sol_viaje)""", ids));
        agregar(elementos, "Ofertas de viaje", contar("select count(*) from oferta_viaje where id_conductor in (:conductores)", ids));
        agregar(elementos, "Mensajes de chat", contar("select count(*) from mensaje where id_usuario_emisor in (:usuarios)", ids));
        agregar(elementos, "Notificaciones", contar("select count(*) from notificacion where id_usuario in (:usuarios)", ids));
        agregar(elementos, "Dispositivos (avisos push)", contar("select count(*) from dispositivo where id_usuario in (:usuarios)", ids));
        agregar(elementos, "Contactos de emergencia", contar("select count(*) from contacto_emergencia where id_usuario in (:usuarios)", ids));
        agregar(elementos, "Lugares favoritos", contar("select count(*) from direccion_guardada where id_pasajero in (:pasajeros)", ids));
        agregar(elementos, "Reportes y alertas SOS", contar("""
                select (select count(*) from reporte where id_usuario_reporta in (:usuarios))
                     + (select count(*) from reporte_comentario where id_usuario_reporta in (:usuarios))
                     + (select count(*) from alerta_sos where id_usuario in (:usuarios))""", ids));
        agregar(elementos, "Documentos PDF del conductor", contar("select count(*) from documento_conductor where id_conductor in (:conductores)", ids));
        agregar(elementos, "QR de cobro", contar("select count(*) from qr_pago_conductor where id_conductor in (:conductores)", ids));
        agregar(elementos, "Motos", contar("select count(*) from vehiculo where id_conductor in (:conductores)", ids));
        agregar(elementos, "Datos de estudiante y matriculas", contar("""
                select (select count(*) from estudiante where id_persona = :persona)
                     + (select count(*) from matricula_estudiante m join estudiante e on e.id_estudiante = m.id_estudiante
                        where e.id_persona = :persona)""", ids));
        long viajes = contar("select count(*) from viaje where id_pasajero in (:pasajeros) or id_conductor in (:conductores)", ids);
        long calificaciones = contar("""
                select count(*) from calificacion where id_usuario_emisor in (:usuarios) or id_usuario_receptor in (:usuarios)""", ids);
        String correo = persona.getCorreo();
        return new ResumenEliminacionResponse(
                idPersona,
                (persona.getNombres() + " " + persona.getApellidos()).trim(),
                correo,
                conComplemento(persona.getCi(), persona.getComplementoCi()),
                elementos,
                viajes,
                calificaciones,
                bloqueo(ids, idUsuarioActual),
                confirmacion(persona));
    }

    /**
     * Borra todo en una sola transaccion. [confirmacion] debe ser el correo de la persona (o su CI si
     * no tiene correo), escrito por el administrador.
     */
    public void eliminar(Long idPersona, String confirmacion, Long idUsuarioActual) {
        Persona persona = buscar(idPersona);
        String esperado = confirmacion(persona);
        if (confirmacion == null || !confirmacion.trim().equalsIgnoreCase(esperado)) {
            throw new NegocioException("Escriba exactamente " + esperado + " para confirmar la eliminacion");
        }
        Ids ids = ids(idPersona);
        String bloqueo = bloqueo(ids, idUsuarioActual);
        if (bloqueo != null) {
            throw new NegocioException(bloqueo);
        }
        // Se calcula antes de borrar: la carpeta se busca por el id y el CI de la persona.
        almacenamientoArchivos.borrarCarpetaPersonaAlConfirmar(persona);

        boolean conViajes = contar("select count(*) from viaje where id_pasajero in (:pasajeros) or id_conductor in (:conductores)", ids) > 0
                || contar("select count(*) from calificacion where id_usuario_emisor in (:usuarios) or id_usuario_receptor in (:usuarios)", ids) > 0;
        if (conViajes) {
            asegurarRegistroEliminado();
        }

        // 1. Lo que se conserva (viajes con otras personas) pasa a "USUARIO ELIMINADO".
        ejecutar("update viaje set id_pasajero = 0 where id_pasajero in (:pasajeros)", ids);
        ejecutar("update viaje set id_conductor = 0 where id_conductor in (:conductores)", ids);
        ejecutar("""
                update viaje set id_estudiante = null where id_estudiante in
                (select id_estudiante from estudiante where id_persona = :persona)""", ids);
        ejecutar("""
                update solicitud_viaje set id_pasajero = 0 where id_pasajero in (:pasajeros)
                and id_sol_viaje in (select id_sol_viaje from viaje)""", ids);
        ejecutar("update calificacion set id_usuario_emisor = 0 where id_usuario_emisor in (:usuarios)", ids);
        ejecutar("update calificacion set id_usuario_receptor = 0 where id_usuario_receptor in (:usuarios)", ids);
        ejecutar("update respuesta_calificacion set id_conductor = 0 where id_conductor in (:conductores)", ids);
        ejecutar("update historial_estado_viaje set id_usuario_cambio = 0 where id_usuario_cambio in (:usuarios)", ids);
        // La placa es unica: la moto conservada la libera (E<id>-) por si la persona vuelve a registrarla.
        ejecutar("""
                update vehiculo set id_conductor = 0, estado_vehiculo = 'X',
                       placa = left('E' || id_vehiculo || '-' || coalesce(placa, ''), 15)
                where id_conductor in (:conductores) and id_vehiculo in (select id_vehiculo from viaje)""", ids);

        // 2. Lo que es solo suyo.
        ejecutar("delete from oferta_viaje where id_conductor in (:conductores)", ids);
        ejecutar("""
                delete from oferta_viaje where id_sol_viaje in (select id_sol_viaje from solicitud_viaje
                where id_pasajero in (:pasajeros))""", ids);
        ejecutar("delete from solicitud_viaje where id_pasajero in (:pasajeros)", ids);
        ejecutar("delete from mensaje where id_usuario_emisor in (:usuarios)", ids);
        ejecutar("delete from notificacion where id_usuario in (:usuarios)", ids);
        ejecutar("delete from dispositivo where id_usuario in (:usuarios)", ids);
        ejecutar("delete from contacto_emergencia where id_usuario in (:usuarios)", ids);
        ejecutar("delete from alerta_sos where id_usuario in (:usuarios)", ids);
        ejecutar("delete from reporte where id_usuario_reporta in (:usuarios)", ids);
        ejecutar("delete from reporte_comentario where id_usuario_reporta in (:usuarios)", ids);
        ejecutar("delete from direccion_guardada where id_pasajero in (:pasajeros)", ids);
        ejecutar("delete from permiso_edicion_conductor where id_conductor in (:conductores)", ids);
        ejecutar("delete from documento_conductor where id_conductor in (:conductores)", ids);
        ejecutar("delete from qr_pago_conductor where id_conductor in (:conductores)", ids);
        ejecutar("delete from billetera_conductor where id_conductor in (:conductores)", ids);
        ejecutar("delete from disponibilidad_conductor where id_conductor in (:conductores)", ids);
        ejecutar("delete from ubicacion_conductor where id_conductor in (:conductores)", ids);
        ejecutar("delete from vehiculo where id_conductor in (:conductores)", ids);
        ejecutar("""
                delete from verificacion_estudiante where id_mat_est in (select m.id_mat_est from matricula_estudiante m
                join estudiante e on e.id_estudiante = m.id_estudiante where e.id_persona = :persona)""", ids);
        ejecutar("""
                delete from matricula_estudiante where id_estudiante in
                (select id_estudiante from estudiante where id_persona = :persona)""", ids);
        ejecutar("""
                delete from tutor_estudiante where id_persona = :persona or id_estudiante in
                (select id_estudiante from estudiante where id_persona = :persona)""", ids);
        ejecutar("delete from estudiante where id_persona = :persona", ids);

        // 3. Sus cuentas y la persona.
        ejecutar("delete from pasajero where id_pasajero in (:pasajeros)", ids);
        ejecutar("delete from conductor where id_conductor in (:conductores)", ids);
        ejecutar("delete from usuario where id_usuario in (:usuarios)", ids);
        ejecutar("delete from persona where id_persona = :persona", ids);

        secuenciasInitializer.ajustar();
    }

    // ------------------------------------------------------------------ apoyo

    /** Ids de la persona, sus cuentas y perfiles. Las listas vacias llevan -1 para que el IN sea valido. */
    private record Ids(long persona, List<Long> usuarios, List<Long> pasajeros, List<Long> conductores) {

        MapSqlParameterSource parametros() {
            return new MapSqlParameterSource()
                    .addValue("persona", persona)
                    .addValue("usuarios", oNinguno(usuarios))
                    .addValue("pasajeros", oNinguno(pasajeros))
                    .addValue("conductores", oNinguno(conductores));
        }

        private static Collection<Long> oNinguno(List<Long> lista) {
            return lista.isEmpty() ? List.of(-1L) : lista;
        }
    }

    private Ids ids(long idPersona) {
        MapSqlParameterSource p = new MapSqlParameterSource("persona", idPersona);
        List<Long> usuarios = jdbc.queryForList("select id_usuario from usuario where id_persona = :persona", p, Long.class);
        MapSqlParameterSource u = new MapSqlParameterSource("usuarios", usuarios.isEmpty() ? List.of(-1L) : usuarios);
        return new Ids(idPersona, usuarios,
                jdbc.queryForList("select id_pasajero from pasajero where id_usuario in (:usuarios)", u, Long.class),
                jdbc.queryForList("select id_conductor from conductor where id_usuario in (:usuarios)", u, Long.class));
    }

    private String bloqueo(Ids ids, Long idUsuarioActual) {
        if (idUsuarioActual != null && ids.usuarios.contains(idUsuarioActual)) {
            return "No puede eliminar su propio registro";
        }
        if (contar("select count(*) from administrador where id_usuario in (:usuarios)", ids) > 0) {
            return "La persona tiene una cuenta de administrador: no se elimina de forma permanente";
        }
        long enCurso = contar("""
                select (select count(*) from solicitud_viaje where id_pasajero in (:pasajeros)
                          and situacion_solicitud in ('PENDIENTE', 'CON_OFERTAS'))
                     + (select count(*) from viaje where (id_pasajero in (:pasajeros) or id_conductor in (:conductores))
                          and situacion_viaje not in ('COMPLETADO', 'CANCELADO'))""", ids);
        if (enCurso > 0) {
            return "Tiene un viaje o una solicitud en curso: espere a que termine o se cancele";
        }
        return null;
    }

    /** Crea una sola vez el registro "USUARIO ELIMINADO" (id 0) que conserva los viajes compartidos. */
    private void asegurarRegistroEliminado() {
        MapSqlParameterSource vacio = new MapSqlParameterSource();
        jdbc.update("""
                insert into persona (id_persona, nombres, apellidos, estado_persona)
                values (0, 'USUARIO', 'ELIMINADO', 'X') on conflict (id_persona) do nothing""", vacio);
        jdbc.update("""
                insert into usuario (id_usuario, id_persona, id_rol, nombre_usuario, password_hash, fecha_registro, estado_usuario)
                select 0, 0, r.id_rol, 'usuario_eliminado', '!', now(), 'X' from rol r where r.codigo = 'PASAJERO'
                on conflict (id_usuario) do nothing""", vacio);
        jdbc.update("""
                insert into pasajero (id_pasajero, id_usuario, estado_pasajero)
                values (0, 0, 'X') on conflict (id_pasajero) do nothing""", vacio);
        jdbc.update("""
                insert into conductor (id_conductor, id_usuario, numero_licencia, situacion_aprobacion, estado_conductor)
                values (0, 0, '-', 'RECHAZADO', 'X') on conflict (id_conductor) do nothing""", vacio);
    }

    private Persona buscar(Long idPersona) {
        if (idPersona == null || idPersona <= ID_ELIMINADO) {
            throw RecursoNoEncontradoException.de("Persona", idPersona);
        }
        return personaRepository.findById(idPersona)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Persona", idPersona));
    }

    private static String confirmacion(Persona persona) {
        if (persona.getCorreo() != null && !persona.getCorreo().isBlank()) {
            return persona.getCorreo().trim().toLowerCase(Locale.ROOT);
        }
        if (persona.getCi() != null && !persona.getCi().isBlank()) {
            return persona.getCi().trim();
        }
        return "ELIMINAR";
    }

    private static String conComplemento(String ci, String complemento) {
        if (ci == null) return null;
        return complemento == null || complemento.isBlank() ? ci : ci + "-" + complemento;
    }

    private long contar(String sql, Ids ids) {
        Long cantidad = jdbc.queryForObject(sql, ids.parametros(), Long.class);
        return cantidad == null ? 0 : cantidad;
    }

    private void ejecutar(String sql, Ids ids) {
        jdbc.update(sql, ids.parametros());
    }

    private static void agregar(List<ResumenEliminacionResponse.Elemento> elementos, String concepto, long cantidad) {
        if (cantidad > 0) elementos.add(new ResumenEliminacionResponse.Elemento(concepto, cantidad));
    }

}
