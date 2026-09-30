package com.taxiuap.backend.identity.service;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.ActualizarDatosCuentaRequest;
import com.taxiuap.backend.identity.dto.ConfirmarDatosCuentaRequest;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.UsuarioResponse;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.CredencialesInvalidasException;
import com.taxiuap.backend.shared.exception.NegocioException;

import lombok.RequiredArgsConstructor;

/**
 * Mi perfil de la app: el pasajero o el conductor solo cambia su correo y su telefono (y la
 * licencia del conductor si esta en blanco). El cambio se aplica despues de confirmar un codigo de
 * 6 digitos enviado al correo actual. Los datos de la persona los comparten sus cuentas de pasajero
 * y conductor; el resto lo cambia la administracion desde el panel.
 *
 * Los cambios pendientes viven en memoria (se pierden al reiniciar: solo hay que pedir otro
 * codigo). Vencen a los 15 minutos, admiten 5 intentos y no se envia mas de uno por minuto.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class DatosCuentaService {

    private final UsuarioRepository usuarioRepository;
    private final ConductorRepository conductorRepository;
    private final PersonaRepository personaRepository;
    private final GestionPersonaService gestionPersonaService;
    private final CredencialesCorreoService credencialesCorreoService;

    private static final long MINUTOS_VIGENCIA = 15;
    private static final int INTENTOS_MAXIMOS = 5;
    private static final Duration ESPERA_REENVIO = Duration.ofSeconds(60);
    private static final SecureRandom AZAR = new SecureRandom();

    /** Cambio pedido por un usuario, a la espera de su codigo. */
    private record Pendiente(String codigo, Instant vence, Instant enviado, int intentos, ActualizarDatosCuentaRequest datos) {
    }

    private final Map<Long, Pendiente> pendientes = new ConcurrentHashMap<>();

    /** La persona termino o salto la guia de inicio de la app: no se vuelve a mostrar. */
    public void marcarGuiaVista(Long idUsuario) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
        usuario.setGuiaVista(true);
    }

    /**
     * Valida el cambio y envia el codigo al correo actual. Devuelve ese correo (oculto a medias) para
     * que la app diga a donde llego.
     */
    public String solicitarCambio(Long idUsuario, ActualizarDatosCuentaRequest datos) {
        Usuario usuario = buscar(idUsuario);
        Persona persona = usuario.getPersona();
        String actual = persona.getCorreo();
        if (actual == null || actual.isBlank()) {
            throw new NegocioException("Tu cuenta no tiene un correo para enviarte el codigo");
        }
        pendientes.values().removeIf(p -> p.vence().isBefore(Instant.now()));
        Pendiente anterior = pendientes.get(idUsuario);
        if (anterior != null && anterior.enviado().plus(ESPERA_REENVIO).isAfter(Instant.now())) {
            throw new NegocioException("Ya te enviamos un codigo. Espera un minuto antes de pedir otro");
        }

        String correo = datos.correo().trim().toLowerCase(Locale.ROOT);
        String telefono = vacioANull(datos.telefono());
        if (personaRepository.existsByCorreoAndIdNot(correo, persona.getId())) {
            throw new ConflictoException("Ese correo ya esta registrado por otra persona");
        }
        if (telefono != null && personaRepository.existsByTelefonoAndIdNot(telefono, persona.getId())) {
            throw new ConflictoException("Ese telefono ya esta registrado por otra persona");
        }
        boolean cambiaLicencia = licenciaEditable(usuario, datos);
        if (correo.equalsIgnoreCase(actual) && java.util.Objects.equals(telefono, vacioANull(persona.getTelefono()))
                && !cambiaLicencia) {
            throw new NegocioException("No cambiaste ningun dato");
        }

        String valor = String.format("%06d", AZAR.nextInt(1_000_000));
        Instant ahora = Instant.now();
        pendientes.put(idUsuario, new Pendiente(valor, ahora.plus(Duration.ofMinutes(MINUTOS_VIGENCIA)), ahora, 0,
                new ActualizarDatosCuentaRequest(correo, telefono, datos.numeroLicencia(), datos.categoriaLicencia())));
        credencialesCorreoService.codigoCambioDatos(persona, valor, MINUTOS_VIGENCIA);
        return ocultar(actual);
    }

    /** Aplica el cambio pendiente si el codigo es correcto. */
    public UsuarioResponse confirmarCambio(Long idUsuario, ConfirmarDatosCuentaRequest confirmacion) {
        Pendiente pendiente = pendientes.get(idUsuario);
        if (pendiente == null || pendiente.vence().isBefore(Instant.now())) {
            pendientes.remove(idUsuario);
            throw new NegocioException("El codigo vencio o no existe. Vuelve a guardar tus datos para pedir otro");
        }
        if (!pendiente.codigo().equals(confirmacion.codigo().trim())) {
            int intentos = pendiente.intentos() + 1;
            if (intentos >= INTENTOS_MAXIMOS) {
                pendientes.remove(idUsuario);
                throw new NegocioException("Demasiados intentos. Vuelve a guardar tus datos para pedir otro codigo");
            }
            pendientes.put(idUsuario, new Pendiente(pendiente.codigo(), pendiente.vence(), pendiente.enviado(),
                    intentos, pendiente.datos()));
            throw new NegocioException("El codigo no es correcto");
        }
        pendientes.remove(idUsuario);

        Usuario usuario = buscar(idUsuario);
        Persona persona = usuario.getPersona();
        ActualizarDatosCuentaRequest datos = pendiente.datos();
        String correoAnterior = persona.getCorreo();
        // Valida correo y telefono unicos otra vez (pudieron ocuparse mientras llegaba el codigo).
        gestionPersonaService.actualizar(persona.getId(), new PersonaRequest(
                persona.getCi(),
                persona.getComplementoCi(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getFechaNacimiento(),
                datos.correo(),
                datos.telefono()));

        if (licenciaEditable(usuario, datos)) {
            Conductor conductor = conductorRepository.findByUsuarioId(idUsuario)
                    .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
            if (vacioANull(conductor.getNumeroLicencia()) == null) {
                conductor.setNumeroLicencia(vacioANull(datos.numeroLicencia()));
            }
            if (vacioANull(conductor.getCategoriaLicencia()) == null) {
                conductor.setCategoriaLicencia(vacioANull(datos.categoriaLicencia()));
            }
        }
        if (correoAnterior != null && !correoAnterior.equalsIgnoreCase(datos.correo())) {
            credencialesCorreoService.avisoCorreoCambiado(persona, correoAnterior);
        }

        return UsuarioResponse.de(usuario);
    }

    /**
     * La licencia (numero o categoria) solo se puede poner desde la app si esta en blanco; una vez
     * registrada la cambia la administracion.
     */
    private boolean licenciaEditable(Usuario usuario, ActualizarDatosCuentaRequest datos) {
        if (!RolSistema.CONDUCTOR.getCodigo().equals(usuario.getRol().getCodigo())) {
            return false;
        }
        Conductor conductor = conductorRepository.findByUsuarioId(usuario.getId()).orElse(null);
        if (conductor == null) {
            return false;
        }
        boolean numero = vacioANull(conductor.getNumeroLicencia()) == null && vacioANull(datos.numeroLicencia()) != null;
        boolean categoria = vacioANull(conductor.getCategoriaLicencia()) == null
                && vacioANull(datos.categoriaLicencia()) != null;
        return numero || categoria;
    }

    private Usuario buscar(Long idUsuario) {
        return usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
    }

    private static String vacioANull(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }

    /** "juan.perez@gmail.com" -> "ju*******@gmail.com". */
    private static String ocultar(String correo) {
        int arroba = correo.indexOf('@');
        if (arroba <= 2) {
            return correo;
        }
        return correo.substring(0, 2) + "*".repeat(arroba - 2) + correo.substring(arroba);
    }
}
