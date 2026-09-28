package com.taxiuap.backend.sistema.entity;

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
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Parametro del sistema que el administrador cambia desde el panel sin reiniciar el backend
 * (por ejemplo la carpeta raiz de los archivos). Una fila por clave.
 */
@Entity
@Table(name = "configuracion_sistema",
        uniqueConstraints = @UniqueConstraint(name = "uk_configuracion_clave", columnNames = "clave"))
@Getter
@Setter
@NoArgsConstructor
public class ConfiguracionSistema extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_config")
    private Integer id;

    @Column(name = "clave", length = 80, nullable = false)
    private String clave;

    @Column(name = "valor", length = 500)
    private String valor;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_config", length = 20)
    private EstadoRegistro estadoConfig = EstadoRegistro.A;
}
