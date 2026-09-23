package com.taxiuap.backend.seed;

import java.util.List;

import org.springframework.stereotype.Component;

import com.taxiuap.backend.institution.entity.Carrera;
import com.taxiuap.backend.institution.entity.Institucion;
import com.taxiuap.backend.institution.entity.TipoInstitucion;
import com.taxiuap.backend.institution.repository.CarreraRepository;
import com.taxiuap.backend.institution.repository.InstitucionRepository;
import com.taxiuap.backend.institution.repository.TipoInstitucionRepository;
import com.taxiuap.backend.location.entity.Zona;
import com.taxiuap.backend.location.repository.ZonaRepository;
import com.taxiuap.backend.rating.entity.EtiquetaCalificacion;
import com.taxiuap.backend.rating.enums.AplicaA;
import com.taxiuap.backend.rating.enums.TipoEtiqueta;
import com.taxiuap.backend.rating.repository.EtiquetaCalificacionRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Siembra los catalogos base de prueba: tipos de institucion, instituciones, carreras,
 * tipos de vehiculo, categorias de servicio, etiquetas de calificacion y zonas de cobertura.
 */
@Component
@RequiredArgsConstructor
@Slf4j
class SeedCatalogos {

    private final TipoInstitucionRepository tipoInstitucionRepository;
    private final InstitucionRepository institucionRepository;
    private final CarreraRepository carreraRepository;
    private final TipoVehiculoRepository tipoVehiculoRepository;
    private final CategoriaServicioRepository categoriaServicioRepository;
    private final EtiquetaCalificacionRepository etiquetaCalificacionRepository;
    private final ZonaRepository zonaRepository;

    /** Resultado de la siembra de catalogos, usado por los demas bloques del seed. */
    record CatalogosSembrados(
            TipoInstitucion universidad,
            Institucion uap,
            List<Carrera> carrerasUap,
            TipoVehiculo sedan,
            TipoVehiculo moto,
            TipoVehiculo van,
            CategoriaServicio sedanEstandar,
            CategoriaServicio sedanEjecutivo,
            CategoriaServicio motoCategoria,
            List<Zona> zonas,
            List<EtiquetaCalificacion> etiquetas) {

        Zona zonaCentro() {
            return zonas.get(0);
        }

        Zona zonaPeriferia() {
            return zonas.get(1);
        }
    }

    CatalogosSembrados sembrar() {
        log.info("Sembrando catalogos...");

        TipoInstitucion universidad = crearTipoInstitucion("UNIVERSIDAD", "Universidad");
        TipoInstitucion instituto = crearTipoInstitucion("INSTITUTO", "Instituto");
        TipoInstitucion colegio = crearTipoInstitucion("COLEGIO", "Colegio");

        Institucion uap = crearInstitucion(universidad, "Universidad Amazonica de Pando", "UAP", "Cobija");
        crearInstitucion(instituto, "Instituto Tecnologico Cobija", "ITC", "Cobija");
        crearInstitucion(colegio, "Colegio Nacional Cobija", "CNC", "Cobija");

        List<Carrera> carrerasUap = List.of(
                crearCarrera(uap, "Ingenieria de Sistemas"),
                crearCarrera(uap, "Ingenieria Civil"),
                crearCarrera(uap, "Derecho"),
                crearCarrera(uap, "Medicina"),
                crearCarrera(uap, "Administracion de Empresas"));

        TipoVehiculo sedan = crearTipoVehiculo("SEDAN", "Auto sedan", 4);
        TipoVehiculo moto = crearTipoVehiculo("MOTO", "Motocicleta", 1);
        TipoVehiculo van = crearTipoVehiculo("VAN", "Camioneta van", 7);

        CategoriaServicio sedanEstandar = crearCategoriaServicio(sedan, "ESTANDAR");
        CategoriaServicio sedanEjecutivo = crearCategoriaServicio(sedan, "EJECUTIVO");
        CategoriaServicio motoCategoria = crearCategoriaServicio(moto, "MOTO");

        List<EtiquetaCalificacion> etiquetas = List.of(
                crearEtiqueta("Conduccion segura", TipoEtiqueta.POSITIVA, AplicaA.CONDUCTOR),
                crearEtiqueta("Puntual", TipoEtiqueta.POSITIVA, AplicaA.CONDUCTOR),
                crearEtiqueta("Vehiculo limpio", TipoEtiqueta.POSITIVA, AplicaA.CONDUCTOR),
                crearEtiqueta("Buen trato", TipoEtiqueta.POSITIVA, AplicaA.PASAJERO),
                crearEtiqueta("Pasajero puntual", TipoEtiqueta.POSITIVA, AplicaA.PASAJERO),
                crearEtiqueta("Respetuoso", TipoEtiqueta.POSITIVA, AplicaA.PASAJERO),
                crearEtiqueta("Conduccion brusca", TipoEtiqueta.NEGATIVA, AplicaA.CONDUCTOR),
                crearEtiqueta("Impuntual", TipoEtiqueta.NEGATIVA, AplicaA.CONDUCTOR),
                crearEtiqueta("Trato descortes", TipoEtiqueta.NEGATIVA, AplicaA.PASAJERO),
                crearEtiqueta("Cancelacion tardia", TipoEtiqueta.NEGATIVA, AplicaA.PASAJERO));

        List<Zona> zonas = List.of(
                crearZona("Centro", GeometriaSeed.poligonoRectangulo(-68.775, -11.035, -68.745, -11.010)),
                crearZona("Periferia", GeometriaSeed.poligonoRectangulo(-68.800, -11.060, -68.745, -11.035)));

        log.info("Catalogos sembrados: {} instituciones, {} carreras UAP, {} tipos de vehiculo, "
                        + "{} categorias de servicio, {} etiquetas de calificacion, {} zonas",
                3, carrerasUap.size(), 3, 3, etiquetas.size(), zonas.size());

        return new CatalogosSembrados(universidad, uap, carrerasUap, sedan, moto, van,
                sedanEstandar, sedanEjecutivo, motoCategoria, zonas, etiquetas);
    }

    private TipoInstitucion crearTipoInstitucion(String codigo, String nombre) {
        return tipoInstitucionRepository.findByCodigo(codigo).orElseGet(() -> {
            TipoInstitucion tipo = new TipoInstitucion();
            tipo.setCodigo(codigo);
            tipo.setNombre(nombre);
            return tipoInstitucionRepository.save(tipo);
        });
    }

    private Institucion crearInstitucion(TipoInstitucion tipo, String nombre, String sigla, String ciudad) {
        Institucion institucion = new Institucion();
        institucion.setTipoInstitucion(tipo);
        institucion.setNombre(nombre);
        institucion.setSigla(sigla);
        institucion.setCiudad(ciudad);
        return institucionRepository.save(institucion);
    }

    private Carrera crearCarrera(Institucion institucion, String nombre) {
        Carrera carrera = new Carrera();
        carrera.setInstitucion(institucion);
        carrera.setNombre(nombre);
        return carreraRepository.save(carrera);
    }

    private TipoVehiculo crearTipoVehiculo(String codigo, String nombre, int capacidad) {
        return tipoVehiculoRepository.findByCodigo(codigo).orElseGet(() -> {
            TipoVehiculo tipo = new TipoVehiculo();
            tipo.setCodigo(codigo);
            tipo.setNombre(nombre);
            tipo.setCapacidadPasajeros(capacidad);
            return tipoVehiculoRepository.save(tipo);
        });
    }

    private CategoriaServicio crearCategoriaServicio(TipoVehiculo tipoVehiculo, String nombre) {
        CategoriaServicio categoria = new CategoriaServicio();
        categoria.setTipoVehiculo(tipoVehiculo);
        categoria.setNombre(nombre);
        return categoriaServicioRepository.save(categoria);
    }

    private EtiquetaCalificacion crearEtiqueta(String nombre, TipoEtiqueta tipo, AplicaA aplicaA) {
        EtiquetaCalificacion etiqueta = new EtiquetaCalificacion();
        etiqueta.setNombre(nombre);
        etiqueta.setTipo(tipo);
        etiqueta.setAplicaA(aplicaA);
        return etiquetaCalificacionRepository.save(etiqueta);
    }

    private Zona crearZona(String nombre, org.locationtech.jts.geom.Polygon poligono) {
        Zona zona = new Zona();
        zona.setNombre(nombre);
        zona.setPoligono(poligono);
        return zonaRepository.save(zona);
    }
}
