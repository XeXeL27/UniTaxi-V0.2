package com.taxiuap.backend.identity.service;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.dto.CambiarContrasenaConCodigoRequest;
import com.taxiuap.backend.identity.dto.CambiarContrasenaRequest;
import com.taxiuap.backend.identity.dto.CodigoContrasenaResponse;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.CredencialesInvalidasException;
import com.taxiuap.backend.shared.exception.NegocioException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Perfil > Cambiar contrasena, con la sesion iniciada. Dos caminos para verificar que es la persona:
 * - la contrasena actual (tras 5 errores seguidos hay que esperar 15 minutos o usar el codigo);
 * - un codigo de 6 digitos enviado al correo REGISTRADO (no se elige otro): vale 15 minutos, admite 5
 *   intentos y se reenvia cada 90 segundos.
 * Verificado, se pide la nueva contrasena. Las cuentas de pasajero y conductor de la persona cambian juntas
 * (regla 12); la de administrador, sola. Al terminar llega un correo de aviso, sin la contrasena.
 *
 * Los codigos y los errores viven en memoria (al reiniciar el servidor solo hay que pedir otro codigo).
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class CambioContrasenaService {

    static final long MINUTOS_VIGENCIA = 15;
    static final int INTENTOS_MAXIMOS = 5;
    static final Duration ESPERA_REENVIO = Duration.ofSeconds(90);
    static final Duration BLOQUEO_CONTRASENA = Duration.ofMinutes(15);
    private static final SecureRandom AZAR = new SecureRandom();

    private record Codigo(String valor, Instant vence, Instant enviado, int intentos) {
    }

    private record Fallos(int cantidad, Instant bloqueadoHasta) {
    }

    /** Por persona: el codigo vale para sus cuentas de pasajero y conductor. */
    private final Map<Long, Codigo> codigos = new ConcurrentHashMap<>();

    /** Por usuario: contrasenas actuales incorrectas seguidas. */
    private final Map<Long, Fallos> fallos = new ConcurrentHashMap<>();

    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;
    private final CuentaUsuarioService cuentaUsuarioService;
    private final CredencialesCorreoService credencialesCorreoService;

    private Clock reloj = Clock.systemDefaultZone();

    /** Solo para las pruebas: mover el tiempo. */
    void usarReloj(Clock reloj) {
        this.reloj = reloj;
    }

    // ---------------------------------------------------------------- con la contrasena actual

    /** Paso 2 con la contrasena actual: la revisa antes de mostrar los campos de la nueva. */
    @Transactional(readOnly = true)
    public void verificarActual(Long idUsuario, String actual) {
        comprobarActual(usuario(idUsuario), actual);
    }

    /** Cambia la contrasena con la actual (tambien lo usan las apps que no tienen los pasos). */
    public void cambiarConActual(Long idUsuario, CambiarContrasenaRequest datos) {
        Usuario usuario = usuario(idUsuario);
        comprobarActual(usuario, datos.actual());
        aplicar(usuario, datos.nueva(), datos.confirmacion());
    }

    private void comprobarActual(Usuario usuario, String actual) {
        Instant ahora = reloj.instant();
        Fallos previos = fallos.get(usuario.getId());
        if (previos != null && previos.bloqueadoHasta() != null && previos.bloqueadoHasta().isAfter(ahora)) {
            throw new NegocioException("Escribiste mal tu contraseña varias veces. Espera "
                    + minutosHasta(previos.bloqueadoHasta(), ahora) + " min o usa el código por correo.");
        }
        if (actual != null && passwordEncoder.matches(actual, usuario.getPasswordHash())) {
            fallos.remove(usuario.getId());
            return;
        }
        int cantidad = (previos == null || previos.bloqueadoHasta() != null ? 0 : previos.cantidad()) + 1;
        if (cantidad >= INTENTOS_MAXIMOS) {
            fallos.put(usuario.getId(), new Fallos(cantidad, ahora.plus(BLOQUEO_CONTRASENA)));
            log.info("Cambio de contrasena bloqueado {} min para el usuario {} por contrasenas incorrectas",
                    BLOQUEO_CONTRASENA.toMinutes(), usuario.getId());
            throw new NegocioException("Escribiste mal tu contraseña " + INTENTOS_MAXIMOS + " veces. Espera "
                    + BLOQUEO_CONTRASENA.toMinutes() + " min o usa el código por correo.");
        }
        fallos.put(usuario.getId(), new Fallos(cantidad, null));
        throw new NegocioException("La contraseña actual no es correcta");
    }

    // ---------------------------------------------------------------- con el codigo del correo

    /** A que correo llegaria el codigo (oculto en parte) y si ya se puede pedir otro. */
    @Transactional(readOnly = true)
    public CodigoContrasenaResponse correo(Long idUsuario) {
        Persona persona = usuario(idUsuario).getPersona();
        return respuesta(persona, segundosParaReenviar(persona, reloj.instant()));
    }

    /** Envia un codigo nuevo al correo registrado de la persona. */
    public CodigoContrasenaResponse enviarCodigo(Long idUsuario) {
        Persona persona = usuario(idUsuario).getPersona();
        if (!tieneCorreo(persona)) {
            throw new NegocioException("Tu cuenta no tiene un correo registrado: usa tu contraseña actual");
        }
        Instant ahora = reloj.instant();
        codigos.values().removeIf(c -> c.vence().isBefore(ahora));
        long faltan = segundosParaReenviar(persona, ahora);
        if (faltan > 0) {
            throw new NegocioException("Ya te enviamos un código. Podrás pedir otro en " + faltan + " s");
        }
        String valor = String.format("%06d", AZAR.nextInt(1_000_000));
        codigos.put(persona.getId(), new Codigo(valor, ahora.plus(Duration.ofMinutes(MINUTOS_VIGENCIA)), ahora, 0));
        credencialesCorreoService.codigoCambioContrasena(persona, valor, MINUTOS_VIGENCIA);
        return respuesta(persona, ESPERA_REENVIO.toSeconds());
    }

    /** Paso 2 con el codigo: lo revisa sin gastarlo (se gasta al guardar la contrasena nueva). */
    @Transactional(readOnly = true)
    public void verificarCodigo(Long idUsuario, String codigo) {
        comprobarCodigo(usuario(idUsuario).getPersona(), codigo);
    }

    public void cambiarConCodigo(Long idUsuario, CambiarContrasenaConCodigoRequest datos) {
        Usuario usuario = usuario(idUsuario);
        comprobarCodigo(usuario.getPersona(), datos.codigo());
        aplicar(usuario, datos.nueva(), datos.confirmacion());
        codigos.remove(usuario.getPersona().getId());
    }

    private void comprobarCodigo(Persona persona, String escrito) {
        Long clave = persona.getId();
        Codigo codigo = codigos.get(clave);
        if (codigo == null || codigo.vence().isBefore(reloj.instant())) {
            codigos.remove(clave);
            throw new NegocioException("El código venció o no existe. Pide uno nuevo");
        }
        if (escrito == null || !codigo.valor().equals(escrito.trim())) {
            int intentos = codigo.intentos() + 1;
            if (intentos >= INTENTOS_MAXIMOS) {
                codigos.remove(clave);
                throw new NegocioException("Demasiados intentos. Pide un código nuevo");
            }
            codigos.put(clave, new Codigo(codigo.valor(), codigo.vence(), codigo.enviado(), intentos));
            throw new NegocioException("El código no es correcto");
        }
    }

    private long segundosParaReenviar(Persona persona, Instant ahora) {
        Codigo anterior = codigos.get(persona.getId());
        if (anterior == null) return 0;
        Instant permitido = anterior.enviado().plus(ESPERA_REENVIO);
        return permitido.isAfter(ahora) ? Duration.between(ahora, permitido).toSeconds() + 1 : 0;
    }

    private static CodigoContrasenaResponse respuesta(Persona persona, long segundosParaReenviar) {
        boolean conCorreo = tieneCorreo(persona);
        return new CodigoContrasenaResponse(conCorreo ? RecuperarCuentaService.ocultar(persona.getCorreo()) : null,
                conCorreo, segundosParaReenviar, MINUTOS_VIGENCIA);
    }

    // ---------------------------------------------------------------- comun

    /** Pone la nueva contrasena y avisa al correo (sin la contrasena). */
    private void aplicar(Usuario usuario, String nueva, String confirmacion) {
        if (!nueva.equals(confirmacion)) {
            throw new NegocioException("La confirmación no coincide con la nueva contraseña");
        }
        if (passwordEncoder.matches(nueva, usuario.getPasswordHash())) {
            throw new NegocioException("La nueva contraseña debe ser distinta de la actual");
        }
        String hash = cuentaUsuarioService.codificar(nueva);
        List<Usuario> cuentas = CredencialesCorreoService.esCuentaDeApp(usuario)
                ? credencialesCorreoService.cuentasDeApp(usuario.getPersona())
                : List.of(usuario);
        cuentas.forEach(u -> {
            u.setPasswordHash(hash);
            u.setContrasenaGenerada(false);
        });
        usuarioRepository.saveAll(cuentas);
        fallos.remove(usuario.getId());
        log.info("Contrasena actualizada desde el perfil por el usuario {} ({} cuenta(s))", usuario.getId(), cuentas.size());
        if (tieneCorreo(usuario.getPersona())) {
            credencialesCorreoService.contrasenaActualizada(usuario.getPersona(), LocalDateTime.now(reloj));
        }
    }

    private Usuario usuario(Long idUsuario) {
        return usuarioRepository.findById(idUsuario)
                .filter(u -> u.getEstadoUsuario() == EstadoRegistro.A)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
    }

    private static boolean tieneCorreo(Persona persona) {
        return persona.getCorreo() != null && persona.getCorreo().contains("@");
    }

    private static long minutosHasta(Instant hasta, Instant ahora) {
        return Math.max(1, (Duration.between(ahora, hasta).toSeconds() + 59) / 60);
    }
}
