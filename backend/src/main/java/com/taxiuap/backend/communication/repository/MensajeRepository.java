package com.taxiuap.backend.communication.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.taxiuap.backend.communication.entity.Mensaje;

/** Repositorio de mensajes de chat. */
public interface MensajeRepository extends JpaRepository<Mensaje, Long> {

    List<Mensaje> findByViajeIdOrderByFechaAsc(Long idViaje);

    long countByViajeIdAndLeidoFalse(Long idViaje);

    /** Mensajes sin leer que no escribio el usuario: los que el otro le dejo. */
    long countByViajeIdAndLeidoFalseAndUsuarioEmisorIdNot(Long idViaje, Long idUsuarioEmisor);

    /** Marca como leidos los mensajes que el otro le dejo al usuario en el viaje. */
    @Modifying
    @Query("UPDATE Mensaje m SET m.leido = true WHERE m.viaje.id = :idViaje "
            + "AND m.usuarioEmisor.id <> :idUsuario AND m.leido = false")
    int marcarLeidosDelOtro(@Param("idViaje") Long idViaje, @Param("idUsuario") Long idUsuario);
}
