package com.taxiuap.backend.identity.service;

import java.time.LocalDateTime;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Dispositivo;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.Plataforma;
import com.taxiuap.backend.identity.repository.DispositivoRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.CredencialesInvalidasException;

import lombok.RequiredArgsConstructor;

/**
 * Telefonos de cada cuenta para las notificaciones push (token de FCM). Un token es de un solo
 * telefono: si en ese telefono entra otra cuenta, el token pasa a la nueva. Al cerrar sesion se da
 * de baja para que no le lleguen avisos de la cuenta anterior.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class DispositivoService {

    private final DispositivoRepository dispositivoRepository;
    private final UsuarioRepository usuarioRepository;

    public void registrar(Long idUsuario, String token, Plataforma plataforma) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
        Dispositivo dispositivo = dispositivoRepository.findByTokenFcm(token.trim()).orElseGet(Dispositivo::new);
        dispositivo.setUsuario(usuario);
        dispositivo.setTokenFcm(token.trim());
        dispositivo.setPlataforma(plataforma == null ? Plataforma.ANDROID : plataforma);
        dispositivo.setUltimaConexion(LocalDateTime.now());
        dispositivo.setEstadoDispos(EstadoRegistro.A);
        dispositivoRepository.save(dispositivo);
    }

    public void darDeBaja(Long idUsuario, String token) {
        dispositivoRepository.findByTokenFcm(token.trim())
                .filter(d -> d.getUsuario().getId().equals(idUsuario))
                .ifPresent(d -> d.setEstadoDispos(EstadoRegistro.X));
    }
}
