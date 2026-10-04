package com.taxiuap.backend.trip.repository;

import java.util.Collection;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.enums.EstadoEntrega;

/** Repositorio de los datos adicionales de solicitudes DELIVERY. */
public interface DatosEntregaRepository extends JpaRepository<DatosEntrega, Long> {

    Optional<DatosEntrega> findBySolicitudId(Long idSolicitud);

    /**
     * Avanza el pedido solo si sigue en uno de los estados permitidos. Es un UPDATE condicional en la
     * base de datos, no una lectura seguida de un save: si dos pantallas actuan sobre el mismo pedido a
     * la vez, el segundo UPDATE no toca ninguna fila y devuelve 0, que el servicio traduce a un
     * rechazo. clearAutomatically/flushAutomatically obligan a releer despues para no trabajar sobre
     * datos que la base ya cambio.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update DatosEntrega d
               set d.estadoEntrega = :nuevo
             where d.id = :id
               and d.estadoEntrega in :permitidos
            """)
    int avanzarSiEstadoPermitido(@Param("id") Long id,
            @Param("permitidos") Collection<EstadoEntrega> permitidos,
            @Param("nuevo") EstadoEntrega nuevo);

    /**
     * Igual que {@link #avanzarSiEstadoPermitido} pero exigiendo ademas el codigo de recogida. El codigo
     * no se compara en Java porque entre leerlo y guardarlo otra pantalla podria haberlo usado.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update DatosEntrega d
               set d.estadoEntrega = :nuevo
             where d.id = :id
               and d.estadoEntrega in :permitidos
               and d.codigoRecogida = :codigo
            """)
    int avanzarSiCodigoRecogidaCoincide(@Param("id") Long id,
            @Param("permitidos") Collection<EstadoEntrega> permitidos,
            @Param("nuevo") EstadoEntrega nuevo,
            @Param("codigo") String codigo);

    /** Igual que {@link #avanzarSiEstadoPermitido} pero exigiendo ademas el codigo de entrega. */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update DatosEntrega d
               set d.estadoEntrega = :nuevo
             where d.id = :id
               and d.estadoEntrega in :permitidos
               and d.codigoEntrega = :codigo
            """)
    int avanzarSiCodigoEntregaCoincide(@Param("id") Long id,
            @Param("permitidos") Collection<EstadoEntrega> permitidos,
            @Param("nuevo") EstadoEntrega nuevo,
            @Param("codigo") String codigo);

    /**
     * "No se pudo entregar" cambia el estado y guarda la evidencia en la misma sentencia: la foto y el
     * motivo son obligatorios, y escribirlos despues dejaria un instante un NO_ENTREGADO sin
     * evidencia que el admin todavia podria leer.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update DatosEntrega d
               set d.estadoEntrega = :nuevo,
                   d.motivoFalla = :motivo,
                   d.fotoFallaUrl = :foto
             where d.id = :id
               and d.estadoEntrega in :permitidos
            """)
    int registrarFallaSiEstadoPermitido(@Param("id") Long id,
            @Param("permitidos") Collection<EstadoEntrega> permitidos,
            @Param("nuevo") EstadoEntrega nuevo,
            @Param("motivo") String motivo,
            @Param("foto") String foto);
}
