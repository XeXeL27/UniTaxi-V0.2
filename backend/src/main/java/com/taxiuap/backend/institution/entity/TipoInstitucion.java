package com.taxiuap.backend.institution.entity;

import com.taxiuap.backend.config.EntidadAuditable;
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

/** Catalogo editable de tipos de institucion educativa (UNIVERSIDAD, COLEGIO, INSTITUTO). */
@Entity
@Table(name = "tipo_institucion")
@Getter
@Setter
@NoArgsConstructor
public class TipoInstitucion extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_tipo_inst")
    private Integer id;

    @Column(name = "codigo", length = 30, nullable = false, unique = true)
    private String codigo;

    @Column(name = "nombre", length = 100, nullable = false)
    private String nombre;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_tipo_inst", length = 20, nullable = false)
    private EstadoRegistro estadoTipoInst = EstadoRegistro.A;
}
