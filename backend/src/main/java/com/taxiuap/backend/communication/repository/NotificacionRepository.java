package com.taxiuap.backend.communication.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.communication.entity.Notificacion;

/** Repositorio de notificaciones. */
public interface NotificacionRepository extends JpaRepository<Notificacion, Long> {

    List<Notificacion> findByUsuarioIdOrderByFechaDesc(Long idUsuario);

    long countByUsuarioIdAndLeidaFalse(Long idUsuario);
}
