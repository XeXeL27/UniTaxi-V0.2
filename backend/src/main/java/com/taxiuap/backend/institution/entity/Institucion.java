package com.taxiuap.backend.institution.entity;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Institucion educativa (universidad, colegio o instituto). */
@Entity
@Table(name = "institucion")
@Getter
@Setter
@NoArgsConstructor
public class Institucion extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_inst")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_tipo_inst", nullable = false)
    private TipoInstitucion tipoInstitucion;

    @Column(name = "nombre", length = 150, nullable = false)
    private String nombre;

    @Column(name = "sigla", length = 30)
    private String sigla;

    @Column(name = "ciudad", length = 100)
    private String ciudad;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_inst", length = 20, nullable = false)
    private EstadoRegistro estadoInst = EstadoRegistro.A;
}
