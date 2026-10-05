package com.taxiuap.backend.testsupport;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Rol;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.RolRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

/**
 * Datos minimos para las pruebas de DELIVERY que corren contra PostgreSQL.
 *
 * Las pruebas no pueden dar por sentado que el seedor de datos de desarrollo dejo un pasajero o una
 * moto DELIVERY: cada perfil (y cada base) siembra una parte distinta. Estas utilidades crean lo que
 * cada prueba necesita, con valores unicos, para que la base de desarrollo no dependa de ellas.
 */
public class DatosPruebaDelivery {

    private static final String CODIGO_MOTO = "MOTO";
    private static final String NOMBRE_CATEGORIA_DELIVERY = "DELIVERY";
    private static final GeometryFactory GEOMETRIA = new GeometryFactory(new PrecisionModel(), 4326);

    private final PersonaRepository personaRepository;
    private final UsuarioRepository usuarioRepository;
    private final RolRepository rolRepository;
    private final PasajeroRepository pasajeroRepository;
    private final ConductorRepository conductorRepository;
    private final VehiculoRepository vehiculoRepository;
    private final TipoVehiculoRepository tipoVehiculoRepository;
    private final CategoriaServicioRepository categoriaServicioRepository;
    private final SolicitudViajeRepository solicitudViajeRepository;
    private final PasswordEncoder passwordEncoder;

    public DatosPruebaDelivery(PersonaRepository personaRepository, UsuarioRepository usuarioRepository,
            RolRepository rolRepository, PasajeroRepository pasajeroRepository,
            ConductorRepository conductorRepository, VehiculoRepository vehiculoRepository,
            TipoVehiculoRepository tipoVehiculoRepository,
            CategoriaServicioRepository categoriaServicioRepository,
            SolicitudViajeRepository solicitudViajeRepository, PasswordEncoder passwordEncoder) {
        this.personaRepository = personaRepository;
        this.usuarioRepository = usuarioRepository;
        this.rolRepository = rolRepository;
        this.pasajeroRepository = pasajeroRepository;
        this.conductorRepository = conductorRepository;
        this.vehiculoRepository = vehiculoRepository;
        this.tipoVehiculoRepository = tipoVehiculoRepository;
        this.categoriaServicioRepository = categoriaServicioRepository;
        this.solicitudViajeRepository = solicitudViajeRepository;
        this.passwordEncoder = passwordEncoder;
    }

    /** El catalogo MOTO siempre debe existir; si el perfil no lo sembro, se crea. */
    public TipoVehiculo tipoMoto() {
        return tipoVehiculoRepository.findByCodigo(CODIGO_MOTO).orElseGet(() -> {
            TipoVehiculo moto = new TipoVehiculo();
            moto.setCodigo(CODIGO_MOTO);
            moto.setNombre("Motocicleta");
            moto.setCapacidadPasajeros(1);
            return tipoVehiculoRepository.saveAndFlush(moto);
        });
    }

    /** Categoria DELIVERY nueva, asociada a una moto. Se crea por prueba a proposito. */
    public CategoriaServicio categoriaDelivery() {
        CategoriaServicio delivery = new CategoriaServicio();
        delivery.setNombre(NOMBRE_CATEGORIA_DELIVERY);
        delivery.setTipoVehiculo(tipoMoto());
        return categoriaServicioRepository.saveAndFlush(delivery);
    }

    public Pasajero crearPasajero() {
        Usuario usuario = crearUsuario("PASAJERO");
        Pasajero pasajero = new Pasajero();
        pasajero.setUsuario(usuario);
        return pasajeroRepository.saveAndFlush(pasajero);
    }

    /** Conductor aprobado, con licencia vigente, que ya puede recibir solicitudes. */
    public Conductor crearConductorAprobado() {
        Usuario usuario = crearUsuario("CONDUCTOR");
        Conductor conductor = new Conductor();
        conductor.setUsuario(usuario);
        conductor.setNumeroLicencia("LIC-" + sufijo());
        conductor.setLicenciaVencimiento(LocalDate.now().plusYears(2));
        conductor.setLimiteAdelantoCompra(new BigDecimal("500.00"));
        conductor.setSituacionAprobacion(SituacionAprobacion.APROBADO);
        return conductorRepository.saveAndFlush(conductor);
    }

    /** Moto DELIVERY activa, lista para aceptar solicitudes de delivery. */
    public Vehiculo crearMotoDelivery(CategoriaServicio delivery) {
        Vehiculo moto = new Vehiculo();
        moto.setConductor(crearConductorAprobado());
        moto.setTipoVehiculo(tipoMoto());
        moto.setCategoriaServicio(delivery);
        moto.setPlaca("PRB-" + sufijo());
        moto.setMarca("Prueba");
        moto.setAnio(2024);
        return vehiculoRepository.saveAndFlush(moto);
    }

    /**
     * Solicitud pendiente con origen y destino, que es lo que exigen las columnas NOT NULL de
     * solicitud_viaje. El precio lo fija la prueba, segun el escenario que este midiendo.
     */
    public SolicitudViaje crearSolicitud(CategoriaServicio categoria, Pasajero pasajero,
            BigDecimal precioSugerido) {
        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(categoria);
        solicitud.setOrigen(punto(-68.75, -11.02));
        solicitud.setDestino(punto(-68.74, -11.03));
        solicitud.setOrigenDireccion("Origen de prueba");
        solicitud.setDestinoDireccion("Destino de prueba");
        solicitud.setPrecioSugerido(precioSugerido);
        solicitud.setSituacionSolicitud(SituacionSolicitud.PENDIENTE);
        solicitud.setFechaSolicitud(LocalDateTime.now());
        solicitud.setEstadoSolViaje(EstadoRegistro.A);
        return solicitudViajeRepository.saveAndFlush(solicitud);
    }

    private Point punto(double longitud, double latitud) {
        return GEOMETRIA.createPoint(new Coordinate(longitud, latitud));
    }

    private Usuario crearUsuario(String codigoRol) {
        Rol rol = rolRepository.findByCodigo(codigoRol)
                .orElseThrow(() -> new IllegalStateException("El rol " + codigoRol + " no fue sembrado"));

        String sufijo = sufijo();
        Persona persona = new Persona();
        persona.setNombres("Persona");
        persona.setApellidos("Prueba");
        persona.setCorreo("prueba." + sufijo + "@example.com");
        persona = personaRepository.saveAndFlush(persona);

        Usuario usuario = new Usuario();
        usuario.setPersona(persona);
        usuario.setRol(rol);
        usuario.setNombreUsuario("prueba." + sufijo);
        usuario.setPasswordHash(passwordEncoder.encode("Prueba123"));
        usuario.setFechaRegistro(LocalDateTime.now());
        return usuarioRepository.saveAndFlush(usuario);
    }

    /** Sufijo unico por registro, para no chocar con las restricciones de correo, usuario y placa. */
    private String sufijo() {
        return UUID.randomUUID().toString().substring(0, 8);
    }
}
