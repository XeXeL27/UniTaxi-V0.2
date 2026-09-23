package com.taxiuap.backend.config;

import java.time.LocalDateTime;

import org.springframework.data.annotation.CreatedBy;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedBy;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.MappedSuperclass;
import lombok.Getter;
import lombok.Setter;

/**
 * Columnas de auditoria comunes a todas las entidades del sistema. Cada entidad conserva ademas
 * su propio campo estado_<entidad> (enum EstadoRegistro) para el borrado logico; eso no vive
 * aqui porque el nombre de columna cambia segun la entidad.
 *
 * creado_por y modificado_por quedan en null cuando la operacion no tiene usuario autenticado
 * (registro publico de pasajero/conductor, inicializadores como AdminInitializer).
 */
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
@Getter
@Setter
public abstract class EntidadAuditable {

    @CreatedDate
    @Column(name = "creado_en", updatable = false)
    private LocalDateTime creadoEn;

    @CreatedBy
    @Column(name = "creado_por", updatable = false)
    private Long creadoPor;

    @LastModifiedDate
    @Column(name = "modificado_en")
    private LocalDateTime modificadoEn;

    @LastModifiedBy
    @Column(name = "modificado_por")
    private Long modificadoPor;
}
