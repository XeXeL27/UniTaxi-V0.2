package com.taxiuap.backend.identity.service;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Base64;
import java.util.Deque;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.taxiuap.backend.institution.dto.DatosSigse;
import com.taxiuap.backend.shared.exception.NegocioException;

/**
 * En memoria (se pierde al reiniciar, lo que solo obliga a volver a escribir el RU):
 * - lo que el SIGSE respondio para el RU de quien se esta registrando, mientras toma las fotos de su
 *   carnet. La app solo recibe un codigo; los datos personales no salen del servidor.
 * - cuantas consultas de RU hizo cada IP en la ultima hora, para que nadie recorra RUs.
 */
@Component
public class ConsultaRuTemporal {

    private record Entrada(DatosSigse datos, Instant vence) {
    }

    private static final Duration VIDA = Duration.ofMinutes(45);
    private static final Duration VENTANA_LIMITE = Duration.ofHours(1);

    private final SecureRandom azar = new SecureRandom();
    private final Map<String, Entrada> registros = new ConcurrentHashMap<>();
    private final Map<String, Deque<Instant>> consultasPorIp = new ConcurrentHashMap<>();
    private final int consultasPorHora;

    public ConsultaRuTemporal(@Value("${taxiuap.sigse.consultas-por-hora:20}") int consultasPorHora) {
        this.consultasPorHora = consultasPorHora;
    }

    public String guardar(DatosSigse datos) {
        limpiarVencidos();
        byte[] bytes = new byte[24];
        azar.nextBytes(bytes);
        String codigo = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        registros.put(codigo, new Entrada(datos, Instant.now().plus(VIDA)));
        return codigo;
    }

    /** Sin consumir: el envio de las fotos puede fallar (datos que no coinciden) y repetirse. */
    public Optional<DatosSigse> ver(String codigo) {
        limpiarVencidos();
        Entrada entrada = codigo == null ? null : registros.get(codigo);
        return entrada == null ? Optional.empty() : Optional.of(entrada.datos());
    }

    public void terminar(String codigo) {
        registros.remove(codigo);
    }

    public void controlarLimite(String ip) {
        Instant ahora = Instant.now();
        Deque<Instant> pedidos = consultasPorIp.computeIfAbsent(ip == null ? "?" : ip, k -> new ArrayDeque<>());
        synchronized (pedidos) {
            while (!pedidos.isEmpty() && pedidos.peekFirst().isBefore(ahora.minus(VENTANA_LIMITE))) {
                pedidos.pollFirst();
            }
            if (pedidos.size() >= consultasPorHora) {
                throw new NegocioException("Hiciste muchas consultas de RU seguidas. Espera unos minutos e intenta de nuevo.");
            }
            pedidos.addLast(ahora);
        }
        if (consultasPorIp.size() > 10_000) {
            consultasPorIp.entrySet().removeIf(e -> e.getValue().isEmpty());
        }
    }

    private void limpiarVencidos() {
        Instant ahora = Instant.now();
        registros.values().removeIf(e -> e.vence().isBefore(ahora));
    }
}
