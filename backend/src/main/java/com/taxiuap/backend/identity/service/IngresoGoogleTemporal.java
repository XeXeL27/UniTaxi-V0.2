package com.taxiuap.backend.identity.service;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Component;

import com.taxiuap.backend.identity.dto.PerfilGoogle;
import com.taxiuap.backend.identity.dto.TokenResponse;
import com.taxiuap.backend.identity.enums.ModoIngresoGoogle;

/**
 * Datos de corta vida del ingreso con Google, en memoria (se pierden al reiniciar, lo que solo
 * obliga a repetir el ingreso):
 *
 * - estado (parametro state de OAuth): liga la vuelta de Google con el pedido que la origino, para
 *   que nadie pueda inyectar un codigo ajeno, y recuerda el modo y a donde volver.
 * - canje: la sesion lista; la app la recoge una sola vez con un codigo que viaja en la URL de
 *   vuelta. Los JWT nunca van en la URL.
 * - registro: el perfil de Google de quien se esta registrando, mientras llena el formulario de
 *   conductor (licencia, moto, PDF) o confirma su carnet de pasajero. Hasta que termina no hay nada
 *   guardado en la BD.
 */
@Component
public class IngresoGoogleTemporal {

    public record Pedido(ModoIngresoGoogle modo, String volver) {
    }

    private record Entrada<T>(T valor, Instant vence) {
    }

    private static final Duration VIDA_ESTADO = Duration.ofMinutes(10);
    private static final Duration VIDA_CANJE = Duration.ofMinutes(2);
    private static final Duration VIDA_REGISTRO = Duration.ofMinutes(45);

    private final SecureRandom azar = new SecureRandom();
    private final Map<String, Entrada<Pedido>> estados = new ConcurrentHashMap<>();
    private final Map<String, Entrada<TokenResponse>> canjes = new ConcurrentHashMap<>();
    private final Map<String, Entrada<PerfilGoogle>> registros = new ConcurrentHashMap<>();

    public String guardarEstado(Pedido pedido) {
        return guardar(estados, pedido, VIDA_ESTADO);
    }

    /** El state solo sirve una vez. */
    public Optional<Pedido> tomarEstado(String estado) {
        return tomar(estados, estado);
    }

    public String guardarCanje(TokenResponse tokens) {
        return guardar(canjes, tokens, VIDA_CANJE);
    }

    public Optional<TokenResponse> tomarCanje(String codigo) {
        return tomar(canjes, codigo);
    }

    public String guardarRegistro(PerfilGoogle perfil) {
        return guardar(registros, perfil, VIDA_REGISTRO);
    }

    /** Consulta sin consumir: el formulario puede fallar (una placa repetida) y volver a enviarse. */
    public Optional<PerfilGoogle> verRegistro(String codigo) {
        limpiarVencidos();
        Entrada<PerfilGoogle> entrada = codigo == null ? null : registros.get(codigo);
        return entrada == null ? Optional.empty() : Optional.of(entrada.valor());
    }

    public void terminarRegistro(String codigo) {
        registros.remove(codigo);
    }

    private <T> String guardar(Map<String, Entrada<T>> mapa, T valor, Duration vida) {
        limpiarVencidos();
        byte[] bytes = new byte[24];
        azar.nextBytes(bytes);
        String codigo = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        mapa.put(codigo, new Entrada<>(valor, Instant.now().plus(vida)));
        return codigo;
    }

    private <T> Optional<T> tomar(Map<String, Entrada<T>> mapa, String codigo) {
        limpiarVencidos();
        Entrada<T> entrada = codigo == null ? null : mapa.remove(codigo);
        return entrada == null ? Optional.empty() : Optional.of(entrada.valor());
    }

    private void limpiarVencidos() {
        Instant ahora = Instant.now();
        estados.values().removeIf(e -> e.vence().isBefore(ahora));
        canjes.values().removeIf(e -> e.vence().isBefore(ahora));
        registros.values().removeIf(e -> e.vence().isBefore(ahora));
    }
}
