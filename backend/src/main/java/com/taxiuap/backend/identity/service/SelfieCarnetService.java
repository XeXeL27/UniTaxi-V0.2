package com.taxiuap.backend.identity.service;

import java.time.LocalDateTime;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/**
 * Cuentas de antes de la foto con el carnet: cada hora da [diasPlazo] dias a quien tiene una cuenta de la
 * app y no la subio (la app se la pide al abrir) y, vencido el plazo, suspende sus cuentas de la app hasta
 * que la suba o hasta que el administrador las habilite (GestionUsuarioService.cambiarEstado). No se
 * suspende a quien tiene el carnet en revision ni una cuenta con un viaje en curso (se intenta en la
 * siguiente vuelta).
 */
@Service
public class SelfieCarnetService {

    private static final Logger log = LoggerFactory.getLogger(SelfieCarnetService.class);

    private final PersonaRepository personaRepository;
    private final CredencialesCorreoService credencialesCorreoService;
    private final GestionUsuarioService gestionUsuarioService;
    private final int diasPlazo;

    public SelfieCarnetService(PersonaRepository personaRepository, CredencialesCorreoService credencialesCorreoService,
            GestionUsuarioService gestionUsuarioService, @Value("${taxiuap.selfie.dias-plazo:7}") int diasPlazo) {
        this.personaRepository = personaRepository;
        this.credencialesCorreoService = credencialesCorreoService;
        this.gestionUsuarioService = gestionUsuarioService;
        this.diasPlazo = diasPlazo;
    }

    @Scheduled(initialDelayString = "PT1M", fixedDelayString = "PT1H")
    @Transactional
    public void revisarPlazos() {
        LocalDateTime ahora = LocalDateTime.now();
        int conPlazo = 0;
        int suspendidas = 0;
        for (Persona persona : personaRepository.sinSelfieCarnet()) {
            List<Usuario> cuentas = credencialesCorreoService.cuentasDeApp(persona);
            if (cuentas.isEmpty()) {
                continue;
            }
            if (persona.getSelfieExigida() == null) {
                persona.setSelfieExigida(true);
                persona.setPlazoSelfieCarnet(ahora.plusDays(diasPlazo));
                conPlazo++;
            } else if (Boolean.TRUE.equals(persona.getSelfieExigida()) && persona.getPlazoSelfieCarnet() != null
                    && persona.getPlazoSelfieCarnet().isBefore(ahora) && !persona.carnetObservado()) {
                for (Usuario cuenta : cuentas) {
                    if (!gestionUsuarioService.tieneViajeEnCurso(cuenta)) {
                        cuenta.setEstadoUsuario(EstadoRegistro.S);
                        persona.setSuspendidaSinSelfie(true);
                        suspendidas++;
                    }
                }
            }
        }
        if (conPlazo > 0 || suspendidas > 0) {
            log.info("Foto con el carnet: {} personas con plazo nuevo de {} dias, {} cuentas suspendidas por no subirla",
                    conPlazo, diasPlazo, suspendidas);
        }
    }
}
