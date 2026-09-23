package com.taxiuap.backend.rating.entity;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.rating.enums.AplicaA;
import com.taxiuap.backend.rating.enums.TipoEtiqueta;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Etiqueta predefinida que se puede asociar a una calificacion. */
@Entity
@Table(name = "etiqueta_calificacion")
@Getter
@Setter
@NoArgsConstructor
public class EtiquetaCalificacion extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_etiq_calif")
    private Integer id;

    @Column(name = "nombre", length = 100)
    private String nombre;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", length = 20)
    private TipoEtiqueta tipo;

    @Enumerated(EnumType.STRING)
    @Column(name = "aplica_a", length = 20)
    private AplicaA aplicaA;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_etiq_calif", length = 20)
    private EstadoRegistro estadoEtiqCalif = EstadoRegistro.A;
}
