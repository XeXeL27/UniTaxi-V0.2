package com.taxiuap.backend.seed;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Rol;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.repository.AdministradorRepository;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.RolRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.institution.entity.Estudiante;
import com.taxiuap.backend.institution.entity.MatriculaEstudiante;
import com.taxiuap.backend.institution.enums.SituacionVerificacion;
import com.taxiuap.backend.institution.repository.EstudianteRepository;
import com.taxiuap.backend.institution.repository.MatriculaEstudianteRepository;
import com.taxiuap.backend.location.entity.DisponibilidadConductor;
import com.taxiuap.backend.location.entity.UbicacionConductor;
import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.location.repository.DisponibilidadConductorRepository;
import com.taxiuap.backend.location.repository.UbicacionConductorRepository;
import com.taxiuap.backend.pricing.entity.BilleteraConductor;
import com.taxiuap.backend.pricing.repository.BilleteraConductorRepository;
import com.taxiuap.backend.seed.SeedCatalogos.CatalogosSembrados;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.DocumentoConductor;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.enums.SituacionRevision;
import com.taxiuap.backend.vehicle.enums.TipoDocumento;
import com.taxiuap.backend.vehicle.repository.DocumentoConductorRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Siembra los usuarios de prueba: un administrador adicional para revisiones, pasajeros
 * (algunos estudiantes verificados de la UAP) y conductores (aprobados con vehiculo y
 * documentos, uno pendiente y uno rechazado), con sus billeteras, disponibilidad y ubicacion.
 */
@Component
@RequiredArgsConstructor
@Slf4j
class SeedUsuarios {

    /** Contrasena unica de todos los usuarios de prueba, hasheada con el PasswordEncoder inyectado. */
    static final String CONTRASENA_PRUEBA = "Taxi123*";

    private final RolRepository rolRepository;
    private final AlmacenamientoArchivos almacenamientoArchivos;
    private final PersonaRepository personaRepository;
    private final UsuarioRepository usuarioRepository;
    private final AdministradorRepository administradorRepository;
    private final PasajeroRepository pasajeroRepository;
    private final ConductorRepository conductorRepository;
    private final EstudianteRepository estudianteRepository;
    private final MatriculaEstudianteRepository matriculaEstudianteRepository;
    private final VehiculoRepository vehiculoRepository;
    private final DocumentoConductorRepository documentoConductorRepository;
    private final BilleteraConductorRepository billeteraConductorRepository;
    private final DisponibilidadConductorRepository disponibilidadConductorRepository;
    private final UbicacionConductorRepository ubicacionConductorRepository;
    private final PasswordEncoder passwordEncoder;

    /** Resultado de la siembra de usuarios, usado por los bloques de precios y viajes. */
    record UsuariosSembrados(
            Administrador adminPruebas,
            List<Pasajero> pasajeros,
            List<Estudiante> estudiantesConMatricula,
            List<Conductor> conductoresAprobados,
            Conductor conductorPendiente,
            Conductor conductorRechazado,
            List<Vehiculo> vehiculosAprobados,
            List<CategoriaServicio> categoriaPorConductorAprobado) {

        Pasajero pasajero(int indice) {
            return pasajeros.get(indice);
        }

        Conductor conductorAprobado(int indice) {
            return conductoresAprobados.get(indice);
        }

        Vehiculo vehiculoAprobado(int indice) {
            return vehiculosAprobados.get(indice);
        }

        CategoriaServicio categoriaAprobado(int indice) {
            return categoriaPorConductorAprobado.get(indice);
        }
    }

    UsuariosSembrados sembrar(CatalogosSembrados catalogos) {
        log.info("Sembrando personas y usuarios de prueba...");

        Rol rolPasajero = obtenerRol(RolSistema.PASAJERO);
        Rol rolConductor = obtenerRol(RolSistema.CONDUCTOR);
        Rol rolAdmin = obtenerRol(RolSistema.ADMIN);

        Administrador adminPruebas = crearAdminPruebas(rolAdmin);

        List<Pasajero> pasajeros = List.of(
                crearPasajero(rolPasajero, "Ana", "Flores", "pasajero1@taxiuap.bo", "70000001"),
                crearPasajero(rolPasajero, "Beatriz", "Mamani", "pasajero2@taxiuap.bo", "70000002"),
                crearPasajero(rolPasajero, "Carlos", "Vaca", "pasajero3@taxiuap.bo", "70000003"),
                crearPasajero(rolPasajero, "Diego", "Rocha", "pasajero4@taxiuap.bo", "70000004"),
                crearPasajero(rolPasajero, "Elena", "Suarez", "pasajero5@taxiuap.bo", "70000005"),
                crearPasajero(rolPasajero, "Fernando", "Rios", "pasajero6@taxiuap.bo", "70000006"),
                crearPasajero(rolPasajero, "Gabriela", "Paz", "pasajero7@taxiuap.bo", "70000007"),
                crearPasajero(rolPasajero, "Hugo", "Cartagena", "pasajero8@taxiuap.bo", "70000008"));

        List<Estudiante> estudiantes = List.of(
                crearEstudianteConMatricula(pasajeros.get(0), catalogos.uap(), catalogos.carrerasUap().get(0),
                        "UAP-2024-0001", SituacionVerificacion.APROBADA),
                crearEstudianteConMatricula(pasajeros.get(1), catalogos.uap(), catalogos.carrerasUap().get(1),
                        "UAP-2024-0002", SituacionVerificacion.APROBADA),
                crearEstudianteConMatricula(pasajeros.get(2), catalogos.uap(), catalogos.carrerasUap().get(2),
                        "UAP-2024-0003", SituacionVerificacion.PENDIENTE),
                crearEstudianteConMatricula(pasajeros.get(3), catalogos.uap(), catalogos.carrerasUap().get(3),
                        "UAP-2024-0004", SituacionVerificacion.RECHAZADA));

        log.info("Sembrando conductores, vehiculos y documentos...");

        Conductor conductorA = crearConductor(rolConductor, "Ivan", "Chavez", "conductor1@taxiuap.bo",
                "70100001", "LIC-00001", SituacionAprobacion.APROBADO);
        Conductor conductorB = crearConductor(rolConductor, "Julia", "Mendez", "conductor2@taxiuap.bo",
                "70100002", "LIC-00002", SituacionAprobacion.APROBADO);
        Conductor conductorC = crearConductor(rolConductor, "Kevin", "Justiniano", "conductor3@taxiuap.bo",
                "70100003", "LIC-00003", SituacionAprobacion.APROBADO);
        Conductor conductorD = crearConductor(rolConductor, "Lucia", "Herrera", "conductor4@taxiuap.bo",
                "70100004", "LIC-00004", SituacionAprobacion.APROBADO);
        Conductor conductorPendiente = crearConductor(rolConductor, "Marco", "Antelo", "conductor5@taxiuap.bo",
                "70100005", "LIC-00005", SituacionAprobacion.PENDIENTE);
        Conductor conductorRechazado = crearConductor(rolConductor, "Nadia", "Salvatierra", "conductor6@taxiuap.bo",
                "70100006", "LIC-00006", SituacionAprobacion.RECHAZADO);

        List<Conductor> conductoresAprobados = List.of(conductorA, conductorB, conductorC, conductorD);
        TipoVehiculo sedan = catalogos.sedan();
        TipoVehiculo moto = catalogos.moto();

        Vehiculo vehiculoA = crearVehiculo(conductorA, sedan, catalogos.sedanEstandar(),
                "1001ABC", "Toyota", "Yaris", "Blanco", 2018);
        Vehiculo vehiculoB = crearVehiculo(conductorB, sedan, catalogos.sedanEjecutivo(),
                "1002ABC", "Nissan", "Sentra", "Negro", 2020);
        Vehiculo vehiculoC = crearVehiculo(conductorC, moto, catalogos.motoCategoria(),
                "1003ABC", "Honda", "CB160", "Rojo", 2021);
        Vehiculo vehiculoD = crearVehiculo(conductorD, sedan, catalogos.sedanEstandar(),
                "1004ABC", "Hyundai", "Accent", "Gris", 2019);

        List<Vehiculo> vehiculosAprobados = List.of(vehiculoA, vehiculoB, vehiculoC, vehiculoD);
        List<CategoriaServicio> categoriasAprobados = List.of(
                catalogos.sedanEstandar(), catalogos.sedanEjecutivo(), catalogos.motoCategoria(), catalogos.sedanEstandar());

        for (int i = 0; i < conductoresAprobados.size(); i++) {
            crearDocumentosAprobados(conductoresAprobados.get(i), vehiculosAprobados.get(i), adminPruebas);
        }

        log.info("Sembrando billeteras, disponibilidad y ubicacion de conductores...");

        crearBilletera(conductorA, new BigDecimal("250.00"));
        crearBilletera(conductorB, new BigDecimal("180.50"));
        crearBilletera(conductorC, new BigDecimal("95.00"));
        crearBilletera(conductorD, new BigDecimal("310.75"));
        crearBilletera(conductorPendiente, BigDecimal.ZERO);
        crearBilletera(conductorRechazado, BigDecimal.ZERO);

        crearDisponibilidadYUbicacion(conductorA, -68.755, -11.018);
        crearDisponibilidadYUbicacion(conductorB, -68.762, -11.025);
        crearDisponibilidadYUbicacion(conductorC, -68.770, -11.030);
        crearDisponibilidadYUbicacion(conductorD, -68.748, -11.015);

        log.info("Usuarios sembrados: 1 administrador de pruebas, {} pasajeros ({} estudiantes con matricula), "
                        + "{} conductores ({} aprobados, 1 pendiente, 1 rechazado)",
                pasajeros.size(), estudiantes.size(), conductoresAprobados.size() + 2, conductoresAprobados.size());

        return new UsuariosSembrados(adminPruebas, pasajeros, estudiantes, conductoresAprobados,
                conductorPendiente, conductorRechazado, vehiculosAprobados, categoriasAprobados);
    }

    private Rol obtenerRol(RolSistema rolSistema) {
        return rolRepository.findByCodigo(rolSistema.getCodigo())
                .orElseThrow(() -> new IllegalStateException(
                        "Rol " + rolSistema.getCodigo() + " no sembrado por AdminInitializer"));
    }

    private Administrador crearAdminPruebas(Rol rolAdmin) {
        Usuario usuario = crearUsuario("Admin", "de Pruebas", "admin.pruebas@taxiuap.bo", "70200000", rolAdmin);
        Administrador administrador = new Administrador();
        administrador.setUsuario(usuario);
        administrador.setCargo("Revisor de documentos y matriculas");
        return administradorRepository.save(administrador);
    }

    private Pasajero crearPasajero(Rol rolPasajero, String nombres, String apellidos, String correo, String telefono) {
        Usuario usuario = crearUsuario(nombres, apellidos, correo, telefono, rolPasajero);
        Pasajero pasajero = new Pasajero();
        pasajero.setUsuario(usuario);
        return pasajeroRepository.save(pasajero);
    }

    private Conductor crearConductor(Rol rolConductor, String nombres, String apellidos, String correo,
            String telefono, String numeroLicencia, SituacionAprobacion situacion) {
        Usuario usuario = crearUsuario(nombres, apellidos, correo, telefono, rolConductor);
        Conductor conductor = new Conductor();
        conductor.setUsuario(usuario);
        conductor.setNumeroLicencia(numeroLicencia);
        conductor.setCategoriaLicencia("B");
        conductor.setSituacionAprobacion(situacion);
        if (situacion == SituacionAprobacion.APROBADO) {
            conductor.setFechaAprobacion(LocalDateTime.now().minusDays(60));
        }
        return conductorRepository.save(conductor);
    }

    private Usuario crearUsuario(String nombres, String apellidos, String correo, String telefono, Rol rol) {
        Persona persona = new Persona();
        persona.setNombres(nombres);
        persona.setApellidos(apellidos);
        persona.setCorreo(correo);
        persona.setTelefono(telefono);
        persona = personaRepository.save(persona);

        // El nombre de usuario de prueba es la parte local del correo (pasajero1, conductor1...).
        Usuario usuario = new Usuario();
        usuario.setPersona(persona);
        usuario.setRol(rol);
        usuario.setNombreUsuario(correo.substring(0, correo.indexOf('@')));
        usuario.setPasswordHash(passwordEncoder.encode(CONTRASENA_PRUEBA));
        usuario.setFechaRegistro(LocalDateTime.now());
        return usuarioRepository.save(usuario);
    }

    private Estudiante crearEstudianteConMatricula(Pasajero pasajero, com.taxiuap.backend.institution.entity.Institucion institucion,
            com.taxiuap.backend.institution.entity.Carrera carrera, String codigoEstudiante, SituacionVerificacion situacion) {
        Persona persona = pasajero.getUsuario().getPersona();

        Estudiante estudiante = new Estudiante();
        estudiante.setPersona(persona);
        estudiante.setInstitucion(institucion);
        estudiante.setCodigoEstudiante(codigoEstudiante);
        estudiante = estudianteRepository.save(estudiante);

        MatriculaEstudiante matricula = new MatriculaEstudiante();
        matricula.setEstudiante(estudiante);
        matricula.setCarrera(carrera);
        matricula.setCursoGrado("3ro");
        matricula.setPeriodoAcademico("2025-II");
        matricula.setPlanEstudio("Plan 2020");
        matricula.setCodigoMatricula(codigoEstudiante);
        matricula.setFechaMatricula(LocalDateTime.now().minusMonths(3));
        matricula.setImagenMatriculaUrl("https://storage.taxiuap.bo/matriculas/" + codigoEstudiante + ".jpg");
        matricula.setSituacionVerificacion(situacion);
        matricula.setFechaVencimiento(LocalDate.now().plusMonths(6));
        matriculaEstudianteRepository.save(matricula);

        return estudiante;
    }

    private Vehiculo crearVehiculo(Conductor conductor, TipoVehiculo tipoVehiculo, CategoriaServicio categoriaServicio,
            String placa, String marca, String modelo, String color, int anio) {
        Vehiculo vehiculo = new Vehiculo();
        vehiculo.setConductor(conductor);
        vehiculo.setTipoVehiculo(tipoVehiculo);
        vehiculo.setCategoriaServicio(categoriaServicio);
        vehiculo.setPlaca(placa);
        vehiculo.setMarca(marca);
        vehiculo.setModelo(modelo);
        vehiculo.setColor(color);
        vehiculo.setAnio(anio);
        return vehiculoRepository.save(vehiculo);
    }

    private void crearDocumentosAprobados(Conductor conductor, Vehiculo vehiculo, Administrador adminRevisor) {
        for (TipoDocumento tipoDocumento : TipoDocumento.values()) {
            DocumentoConductor documento = new DocumentoConductor();
            documento.setConductor(conductor);
            documento.setVehiculo(vehiculo);
            documento.setAdminRevisor(adminRevisor);
            documento.setTipoDocumento(tipoDocumento);
            Persona persona = conductor.getUsuario().getPersona();
            byte[] pdf = PdfEjemploSeed.generar(tipoDocumento.name(),
                    persona.getNombres() + " " + persona.getApellidos() + " - licencia " + conductor.getNumeroLicencia());
            documento.setArchivoUrl(almacenamientoArchivos.guardarPdf(pdf,
                    almacenamientoArchivos.carpetaDocumentosConductor(persona), tipoDocumento.name()));
            documento.setFechaVencimiento(LocalDate.now().plusYears(1));
            documento.setSituacionRevision(SituacionRevision.APROBADO);
            documentoConductorRepository.save(documento);
        }
    }

    private void crearBilletera(Conductor conductor, BigDecimal saldoInicial) {
        BilleteraConductor billetera = new BilleteraConductor();
        billetera.setConductor(conductor);
        billetera.setSaldo(saldoInicial);
        billetera.setDeudaComision(BigDecimal.ZERO);
        billetera.setActualizadoEn(LocalDateTime.now());
        billeteraConductorRepository.save(billetera);
    }

    private void crearDisponibilidadYUbicacion(Conductor conductor, double longitud, double latitud) {
        DisponibilidadConductor disponibilidad = new DisponibilidadConductor();
        disponibilidad.setConductor(conductor);
        disponibilidad.setDisponibilidad(Disponibilidad.DISPONIBLE);
        disponibilidad.setDesde(LocalDateTime.now().minusHours(2));
        disponibilidadConductorRepository.save(disponibilidad);

        UbicacionConductor ubicacion = new UbicacionConductor();
        ubicacion.setConductor(conductor);
        // Coordenadas dentro de Cobija. En WKT/JTS el orden de un punto es (longitud, latitud).
        ubicacion.setUbicacion(GeometriaSeed.punto(longitud, latitud));
        ubicacion.setRumbo(new BigDecimal("90.00"));
        ubicacion.setVelocidad(new BigDecimal("0.00"));
        ubicacion.setActualizadoEn(LocalDateTime.now());
        ubicacionConductorRepository.save(ubicacion);
    }
}
