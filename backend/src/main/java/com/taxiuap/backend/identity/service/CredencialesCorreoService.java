package com.taxiuap.backend.identity.service;

import java.security.SecureRandom;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.service.CorreoService;
import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

import lombok.RequiredArgsConstructor;

/**
 * Contrasenas que genera el sistema y los correos que las entregan. Solo se envia una contrasena
 * cuando el sistema la acaba de crear: las que eligio la persona no se pueden leer (BCrypt).
 *
 * - Pasajero con Google: al registrarse recibe su usuario y una contrasena legible.
 * - Conductor: no recibe nada al registrarse; recien cuando el admin lo aprueba. Si su contrasena
 *   la genero el sistema (usuario.contrasena_generada, registro con Google) se le crea una nueva
 *   y se la envia; si la eligio el, se le recuerda el usuario.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class CredencialesCorreoService {

    /** Sin letras ni numeros que se confunden al leerlos (0/O, 1/l/I). */
    private static final String LETRAS = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ";
    private static final String NUMEROS = "23456789";
    private static final SecureRandom AZAR = new SecureRandom();

    private static final String FIRMA = "\n\nSaludos,\nEquipo Unitaxi";
    private static final String CAMBIAR = "Puedes cambiar tu contraseña cuando quieras en la app, en Más > Cambiar contraseña.";

    private final UsuarioRepository usuarioRepository;
    private final CuentaUsuarioService cuentaUsuarioService;
    private final CorreoService correoService;

    /** Direccion del servidor para el enlace "Iniciar sesion" (abre la app o la web, ver /ingresar). */
    @Value("${taxiuap.url-publica:http://localhost:8080}")
    private String urlPublica;

    /** 10 caracteres faciles de copiar: 8 letras y 2 numeros mezclados. */
    public static String contrasenaLegible() {
        char[] c = new char[10];
        for (int i = 0; i < c.length; i++) c[i] = LETRAS.charAt(AZAR.nextInt(LETRAS.length()));
        int primero = AZAR.nextInt(c.length);
        int segundo = (primero + 1 + AZAR.nextInt(c.length - 1)) % c.length;
        c[primero] = NUMEROS.charAt(AZAR.nextInt(NUMEROS.length()));
        c[segundo] = NUMEROS.charAt(AZAR.nextInt(NUMEROS.length()));
        return new String(c);
    }

    /**
     * Pone la contrasena en todas las cuentas de la app de la persona (regla 12: pasajero y
     * conductor comparten credenciales) y marca si la persona la conoce o no.
     */
    public void aplicarEnCuentasDeApp(Persona persona, String contrasena, boolean generadaSinEntregar) {
        String hash = cuentaUsuarioService.codificar(contrasena);
        List<Usuario> cuentas = cuentasDeApp(persona);
        cuentas.forEach(u -> {
            u.setPasswordHash(hash);
            u.setContrasenaGenerada(generadaSinEntregar);
        });
        usuarioRepository.saveAll(cuentas);
    }

    public List<Usuario> cuentasDeApp(Persona persona) {
        return usuarioRepository.findByPersonaId(persona.getId()).stream()
                .filter(u -> u.getEstadoUsuario() == EstadoRegistro.A)
                .filter(u -> esCuentaDeApp(u))
                .toList();
    }

    public static boolean esCuentaDeApp(Usuario usuario) {
        String codigo = usuario.getRol().getCodigo();
        return RolSistema.PASAJERO.getCodigo().equals(codigo) || RolSistema.CONDUCTOR.getCodigo().equals(codigo);
    }

    /** contrasena null: la persona ya la conoce (la eligio o es la de su otra cuenta). */
    public void bienvenidaPasajero(Usuario usuario, String contrasena, String origenContrasena) {
        Persona persona = usuario.getPersona();
        String cuerpo = saludo(persona)
                + "Tu cuenta de pasajero en Unitaxi ya está lista. Estos son tus datos de ingreso:\n\n"
                + "Usuario: " + usuario.getNombreUsuario() + "\n"
                + "Contraseña: " + (contrasena != null ? contrasena : origenContrasena) + "\n\n"
                + "También puedes seguir ingresando con Google. "
                + (contrasena != null ? CAMBIAR : "")
                + enlace("PASAJERO")
                + FIRMA;
        correoService.enviar(persona.getCorreo(), "Bienvenido a Unitaxi", cuerpo);
    }

    /**
     * Aviso de conductor aprobado. Si el sistema habia generado su contrasena (nadie la conoce) se
     * crea una nueva y se envia; si la eligio la persona, solo se le recuerda el usuario.
     */
    public void conductorAprobado(Usuario usuario) {
        Persona persona = usuario.getPersona();
        if (persona.getCorreo() == null || persona.getCorreo().isBlank()) return;

        String contrasena = null;
        if (Boolean.TRUE.equals(usuario.getContrasenaGenerada())) {
            contrasena = contrasenaLegible();
            aplicarEnCuentasDeApp(persona, contrasena, false);
        }
        String cuerpo = saludo(persona)
                + "Revisamos tus datos y tu cuenta de conductor fue aprobada. Ya puedes recibir viajes en Unitaxi.\n\n"
                + "Usuario: " + usuario.getNombreUsuario() + "\n"
                + "Contraseña: " + (contrasena != null ? contrasena : "la que ya usas para ingresar a Unitaxi") + "\n\n"
                + "Ingresa a la app, elige Conductor y conéctate para ver las solicitudes. "
                + (contrasena != null ? CAMBIAR : "Si no la recuerdas, usa ¿Olvidaste tu contraseña? en el inicio de sesión.")
                + enlace("CONDUCTOR")
                + FIRMA;
        correoService.enviar(persona.getCorreo(), "Tu cuenta de conductor fue aprobada", cuerpo);
    }

    public void codigoRestablecer(Persona persona, String codigo, long minutos) {
        String cuerpo = saludo(persona)
                + "Tu código para restablecer la contraseña de Unitaxi es:\n\n"
                + "    " + codigo + "\n\n"
                + "Vence en " + minutos + " minutos. Si no lo pediste, puedes ignorar este correo."
                + enlace("PASAJERO")
                + FIRMA;
        correoService.enviar(persona.getCorreo(), "Código para restablecer tu contraseña", cuerpo);
    }

    /** En el celular con la app instalada la abre; si no, abre la web (/app o /admin). */
    private String enlace(String rol) {
        String base = urlPublica.endsWith("/") ? urlPublica.substring(0, urlPublica.length() - 1) : urlPublica;
        return "\n\nIniciar sesión: " + base + "/ingresar?rol=" + rol;
    }

    private static String saludo(Persona persona) {
        String nombre = persona.getNombres() == null ? "" : " " + persona.getNombres().trim().split("\\s+")[0];
        return "Hola" + nombre + ":\n\n";
    }
}
