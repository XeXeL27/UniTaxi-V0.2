package com.taxiuap.backend.trip.repository;

import java.time.LocalDateTime;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.trip.entity.PropuestaCostoEntrega;
import com.taxiuap.backend.trip.enums.SituacionPropuestaCosto;

public interface PropuestaCostoEntregaRepository extends JpaRepository<PropuestaCostoEntrega, Long> {

    Optional<PropuestaCostoEntrega> findFirstByDatosEntregaIdOrderByVersionDesc(Long idDatosEntrega);

    /**
     * El cliente acepta la propuesta solo si sigue PENDIENTE. Es un UPDATE condicional: si el repartidor
     * la reemplazo al mismo tiempo (corrigio un precio), no toca ninguna fila y el cliente ve el nuevo total.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update PropuestaCostoEntrega p
               set p.situacionPropuesta = com.taxiuap.backend.trip.enums.SituacionPropuestaCosto.ACEPTADA,
                   p.fechaRespuesta = :ahora,
                   p.usuarioAcepta = :usuario
             where p.id = :id
               and p.situacionPropuesta = com.taxiuap.backend.trip.enums.SituacionPropuestaCosto.PENDIENTE
            """)
    int aceptarSiPendiente(@Param("id") Long id, @Param("usuario") Usuario usuario,
            @Param("ahora") LocalDateTime ahora);

    /** La propuesta vigente (pendiente o ya aceptada) deja de valer: el repartidor corrigio los precios. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update PropuestaCostoEntrega p
               set p.situacionPropuesta = com.taxiuap.backend.trip.enums.SituacionPropuestaCosto.REEMPLAZADA
             where p.datosEntrega.id = :idDatos
               and p.situacionPropuesta in :vigentes
            """)
    int reemplazarVigentes(@Param("idDatos") Long idDatos,
            @Param("vigentes") java.util.Collection<SituacionPropuestaCosto> vigentes);
}
