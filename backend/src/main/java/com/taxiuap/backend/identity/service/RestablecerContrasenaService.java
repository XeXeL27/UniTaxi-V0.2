package com.taxiuap.backend.identity.service;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.dto.CompletarCorreoRequest;
import com.taxiuap.backend.identity.dto.RestablecerContrasenaRequest;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.CredencialesInvalidasException;
import com.taxiuap.backend.shared.exception.NegocioException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * "Olvide mi contrasena" de la app: se envia un codigo de 6 digitos al correo de la persona y con
 * el se pone una contrasena nueva en sus cuentas de pasajero y conductor (regla 12).
 *
 * Los codigos viven en memoria (se pierden al reiniciar: solo hay que pedir otro). Vencen a los 15
 * minutos, admiten 5 intentos y no se envia mas de uno por minuto al mismo correo. La respuesta de
 * "olvide" es siempre la misma, exista o no el correo, para no revelar quien esta registrado.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class RestablecerContrasenaService {

    private static final long MINUTOS_VIGENCIA = 15;
    private static final int INTENTOS_MAXIMOS = 5;
    private static final Duration ESPERA_REENVIO = Duration.ofSeconds(60);
    private static final SecureRandom AZAR = new SecureRandom();

    private record Codigo(String valor, Instant vence, Instant enviado, int intentos) {
    }

    private final Map<String, Codigo> codigos = new ConcurrentHashMap<>();

    private final PersonaRepository personaRepository;
    private final UsuarioRepository usuarioRepository;
    private final CredencialesCorreoService credencialesCorreoService;

    public void enviarCodigo(String correo) {
        String clave = normalizar(correo);
        codigos.values().removeIf(c -> c.vence().isBefore(Instant.now()));
        Codigo anterior = codigos.get(clave);
        if (anterior != null && anterior.enviado().plus(ESPERA_REENVIO).isAfter(Instant.now())) {
            throw new NegocioException("Ya te enviamos un codigo. Espera un minuto antes de pedir otro");
        }

        Optional<Persona> persona = personaConCuentas(clave);
        if (persona.isEmpty()) {
            log.info("Codigo de restablecimiento pedido para un correo sin cuentas de la app: {}", clave);
            return;
        }
        String valor = String.format("%06d", AZAR.nextInt(1_000_000));
        Instant ahora = Instant.now();
        codigos.put(clave, new Codigo(valor, ahora.plus(Duration.ofMinutes(MINUTOS_VIGENCIA)), ahora, 0));
        credencialesCorreoService.codigoRestablecer(persona.get(), valor, MINUTOS_VIGENCIA);
    }

    public void restablecer(RestablecerContrasenaRequest datos) {
        String clave = normalizar(datos.correo());
        Codigo codigo = codigos.get(clave);
        if (codigo == null || codigo.vence().isBefore(Instant.now())) {
            codigos.remove(clave);
            throw new NegocioException("El codigo vencio o no existe. Pide uno nuevo");
        }
        if (!codigo.valor().equals(datos.codigo().trim())) {
            int intentos = codigo.intentos() + 1;
            if (intentos >= INTENTOS_MAXIMOS) {
                codigos.remove(clave);
                throw new NegocioException("Demasiados intentos. Pide un codigo nuevo");
            }
            codigos.put(clave, new Codigo(codigo.valor(), codigo.vence(), codigo.enviado(), intentos));
            throw new NegocioException("El codigo no es correcto");
        }
        if (!datos.nueva().equals(datos.confirmacion())) {
            throw new NegocioException("La confirmacion no coincide con la nueva contrasena");
        }

        Persona persona = personaConCuentas(clave)
                .orElseThrow(() -> new NegocioException("El codigo vencio o no existe. Pide uno nuevo"));
        codigos.remove(clave);
        credencialesCorreoService.aplicarEnCuentasDeApp(persona, datos.nueva(), false);
    }

    /**
     * Correo de quien entro a la app y su persona no tiene uno (cuentas creadas por el admin sin
     * correo). Con correo ya registrado se cambia desde el perfil.
     */
    public String completarCorreo(Long idUsuario, CompletarCorreoRequest datos) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
        Persona persona = usuario.getPersona();
        if (persona.getCorreo() != null && !persona.getCorreo().isBlank()) {
            throw new NegocioException("Tu cuenta ya tiene un correo");
        }
        String correo = normalizar(datos.correo());
        if (personaRepository.existsByCorreoAndIdNot(correo, persona.getId())) {
            throw new ConflictoException("Ese correo ya esta registrado por otra persona");
        }
        persona.setCorreo(correo);
        personaRepository.save(persona);
        return correo;
    }

    private Optional<Persona> personaConCuentas(String correo) {
        return personaRepository.findByCorreo(correo)
                .filter(p -> p.getEstadoPersona() == EstadoRegistro.A)
                .filter(p -> !cuentasDeApp(p).isEmpty());
    }

    private List<Usuario> cuentasDeApp(Persona persona) {
        return credencialesCorreoService.cuentasDeApp(persona);
    }

    private static String normalizar(String correo) {
        return correo == null ? "" : correo.trim().toLowerCase(Locale.ROOT);
    }
}
