package com.taxiuap.backend.institution.service;

import java.text.Normalizer;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.institution.dto.DatosSigse;
import com.taxiuap.backend.institution.dto.EstadoEstudianteResponse;
import com.taxiuap.backend.institution.entity.Carrera;
import com.taxiuap.backend.institution.entity.Estudiante;
import com.taxiuap.backend.institution.entity.Institucion;
import com.taxiuap.backend.institution.entity.MatriculaEstudiante;
import com.taxiuap.backend.institution.entity.TipoInstitucion;
import com.taxiuap.backend.institution.enums.SituacionVerificacion;
import com.taxiuap.backend.institution.repository.CarreraRepository;
import com.taxiuap.backend.institution.repository.EstudianteRepository;
import com.taxiuap.backend.institution.repository.InstitucionRepository;
import com.taxiuap.backend.institution.repository.MatriculaEstudianteRepository;
import com.taxiuap.backend.institution.repository.TipoInstitucionRepository;
import com.taxiuap.backend.pricing.service.ParametrosPrecioService;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Estudiantes de la UAP verificados con el SIGSE. Una persona es estudiante (y tiene el descuento fijo
 * de los viajes) mientras su matricula UAP este APROBADA y vigente. La vigencia dura
 * taxiuap.sigse.dias-vigencia dias (30); al vencer se vuelve a consultar el SIGSE y, si sigue
 * matriculado (estado_matriculacion = true), se renueva sola.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class EstudianteUapService {

    static final String SIGLA_UAP = "UAP";
    private static final String NO_ENCONTRADO =
            "No encontramos ese RU en la UAP. Revisa el número; si está bien, intenta de nuevo en unos minutos.";

    private final ClienteSigse clienteSigse;
    private final EstudianteRepository estudianteRepository;
    private final MatriculaEstudianteRepository matriculaRepository;
    private final InstitucionRepository institucionRepository;
    private final TipoInstitucionRepository tipoInstitucionRepository;
    private final CarreraRepository carreraRepository;
    private final ParametrosPrecioService parametrosPrecioService;

    @Value("${taxiuap.sigse.dias-vigencia:30}")
    private int diasVigencia = 30;

    /** Datos del RU en el SIGSE; 404 si no existe y 422 si no esta matriculado. */
    public DatosSigse consultarMatriculado(String ru) {
        DatosSigse datos = clienteSigse.consultar(ru.trim())
                .orElseThrow(() -> new RecursoNoEncontradoException(NO_ENCONTRADO));
        if (!datos.matriculado()) {
            throw new NegocioException("Ese RU no figura como matriculado en la gestión actual de la UAP");
        }
        return datos;
    }

    public DatosSigse consultar(String ru) {
        return clienteSigse.consultar(ru.trim())
                .orElseThrow(() -> new RecursoNoEncontradoException(NO_ENCONTRADO));
    }

    /**
     * Que datos de la persona (los de su carnet) no coinciden con el SIGSE: "tu nombre", "tu numero
     * de carnet", "tu fecha de nacimiento". El nombre se compara sin tildes ni Ñ y sin espacios de mas.
     */
    public static List<String> diferencias(DatosSigse sigse, String ci, LocalDate fechaNacimiento, String nombres,
            String apellidos) {
        List<String> distintos = new ArrayList<>();
        String nombreCarnet = normalizar((nombres == null ? "" : nombres) + " " + (apellidos == null ? "" : apellidos));
        if (!nombreCarnet.equals(normalizar(sigse.nombreCompleto()))) distintos.add("tu nombre");
        if (ci == null || sigse.ci() == null || !soloDigitos(ci).equals(soloDigitos(sigse.ci()))) {
            distintos.add("tu número de carnet");
        }
        if (fechaNacimiento == null || !fechaNacimiento.equals(sigse.fechaNacimiento())) {
            distintos.add("tu fecha de nacimiento");
        }
        return distintos;
    }

    public static List<String> diferencias(DatosSigse sigse, Persona persona) {
        return diferencias(sigse, persona.getCi(), persona.getFechaNacimiento(), persona.getNombres(),
                persona.getApellidos());
    }

    /** "tu nombre y tu fecha de nacimiento". */
    public static String enFrase(List<String> distintos) {
        if (distintos.size() <= 1) return String.join("", distintos);
        return String.join(", ", distintos.subList(0, distintos.size() - 1)) + " y " + distintos.getLast();
    }

    /**
     * Deja a la persona como estudiante de la UAP con el RU y la carrera del SIGSE: APROBADA (con
     * descuento desde ya), PENDIENTE (registro observado: lo decide el administrador).
     */
    @Transactional
    public MatriculaEstudiante marcarEstudiante(Persona persona, DatosSigse sigse, SituacionVerificacion situacion) {
        Institucion uap = uap();
        estudianteRepository.findByCodigoEstudianteAndInstitucionId(sigse.ru(), uap.getId()).stream()
                .filter(e -> e.getEstadoEstudiante() == EstadoRegistro.A)
                .filter(e -> e.getPersona().getEstadoPersona() == EstadoRegistro.A)
                .filter(e -> !e.getPersona().getId().equals(persona.getId()))
                .findFirst()
                .ifPresent(e -> {
                    throw new ConflictoException("Ese RU ya está registrado como estudiante en otra cuenta de UNITAXI");
                });

        Estudiante estudiante = estudianteRepository.findByPersonaId(persona.getId()).orElseGet(() -> {
            Estudiante nuevo = new Estudiante();
            nuevo.setPersona(persona);
            return nuevo;
        });
        estudiante.setInstitucion(uap);
        estudiante.setCodigoEstudiante(sigse.ru());
        estudiante.setEstadoEstudiante(EstadoRegistro.A);
        estudiante = estudianteRepository.save(estudiante);

        MatriculaEstudiante matricula = ultimaMatricula(estudiante).orElseGet(MatriculaEstudiante::new);
        matricula.setEstudiante(estudiante);
        matricula.setCarrera(carrera(uap, sigse.carrera()));
        matricula.setPeriodoAcademico(sigse.periodoAcademico());
        matricula.setPlanEstudio(sigse.plan());
        matricula.setCodigoMatricula(sigse.ru());
        matricula.setFechaMatricula(LocalDateTime.now());
        matricula.setSituacionVerificacion(situacion);
        matricula.setFechaVencimiento(situacion == SituacionVerificacion.APROBADA
                ? LocalDate.now().plusDays(diasVigencia) : null);
        matricula.setEstadoMatEst(EstadoRegistro.A);
        return matriculaRepository.save(matricula);
    }

    /**
     * El administrador reviso un registro observado de estudiante: [comoEstudiante] true lo aprueba
     * como estudiante (con descuento); false lo deja como pasajero normal (matricula RECHAZADA).
     */
    @Transactional
    public void resolverRevision(Persona persona, boolean comoEstudiante) {
        pendiente(persona).ifPresent(m -> {
            m.setSituacionVerificacion(comoEstudiante ? SituacionVerificacion.APROBADA : SituacionVerificacion.RECHAZADA);
            m.setFechaVencimiento(comoEstudiante ? LocalDate.now().plusDays(diasVigencia) : null);
        });
    }

    /** Registro rechazado por el administrador: deja de ser estudiante y su RU queda libre. */
    @Transactional
    public void quitarEstudiante(Persona persona) {
        estudianteUap(persona).ifPresent(e -> {
            ultimaMatricula(e).ifPresent(m -> m.setSituacionVerificacion(SituacionVerificacion.RECHAZADA));
            e.setEstadoEstudiante(EstadoRegistro.X);
        });
    }

    /** RU de la matricula UAP que espera la revision del administrador (registro observado), si hay. */
    public Optional<String> ruPendiente(Persona persona) {
        return pendiente(persona).map(MatriculaEstudiante::getCodigoMatricula);
    }

    public EstadoEstudianteResponse estado(Persona persona) {
        Optional<Estudiante> estudiante = estudianteUap(persona);
        if (estudiante.isEmpty()) return EstadoEstudianteResponse.ninguno();
        Optional<MatriculaEstudiante> ultima = ultimaMatricula(estudiante.get());
        if (ultima.isEmpty()) return EstadoEstudianteResponse.ninguno();
        MatriculaEstudiante m = ultima.get();
        String situacion = switch (m.getSituacionVerificacion()) {
            case APROBADA -> m.getFechaVencimiento() != null && m.getFechaVencimiento().isBefore(LocalDate.now())
                    ? "VENCIDO" : "VERIFICADO";
            case VENCIDA -> "VENCIDO";
            case PENDIENTE -> "PENDIENTE";
            case RECHAZADA -> "RECHAZADO";
        };
        return new EstadoEstudianteResponse(situacion, estudiante.get().getCodigoEstudiante(),
                m.getCarrera() != null ? m.getCarrera().getNombre() : null, m.getPeriodoAcademico(),
                m.getFechaVencimiento(),
                "VERIFICADO".equals(situacion) ? parametrosPrecioService.actuales().descuentoEstudiante() : null,
                false);
    }

    /**
     * Si la matricula del estudiante vencio, vuelve a preguntar al SIGSE: sigue matriculado y con los
     * mismos datos -> se renueva; ya no esta matriculado -> queda VENCIDA (sin descuento). Si el SIGSE
     * no responde no cambia nada (se reintenta la proxima vez).
     */
    @Transactional
    public EstadoEstudianteResponse renovarSiVencio(Persona persona) {
        EstadoEstudianteResponse actual = estado(persona);
        if (!"VENCIDO".equals(actual.situacion()) || actual.ru() == null) return actual;
        try {
            Optional<DatosSigse> sigse = clienteSigse.consultar(actual.ru());
            if (sigse.isPresent() && sigse.get().matriculado() && diferencias(sigse.get(), persona).isEmpty()) {
                marcarEstudiante(persona, sigse.get(), SituacionVerificacion.APROBADA);
            } else {
                estudianteUap(persona).flatMap(this::ultimaMatricula)
                        .ifPresent(m -> m.setSituacionVerificacion(SituacionVerificacion.VENCIDA));
            }
        } catch (NegocioException e) {
            log.info("No se pudo renovar la matricula de la persona {}: {}", persona.getId(), e.getMessage());
            return actual;
        }
        return estado(persona);
    }

    // ------------------------------------------------------------------ apoyo

    private Optional<Estudiante> estudianteUap(Persona persona) {
        return estudianteRepository.findByPersonaId(persona.getId())
                .filter(e -> e.getEstadoEstudiante() == EstadoRegistro.A)
                .filter(e -> e.getInstitucion() != null && SIGLA_UAP.equalsIgnoreCase(e.getInstitucion().getSigla()));
    }

    private Optional<MatriculaEstudiante> pendiente(Persona persona) {
        return estudianteUap(persona).flatMap(this::ultimaMatricula)
                .filter(m -> m.getSituacionVerificacion() == SituacionVerificacion.PENDIENTE);
    }

    private Optional<MatriculaEstudiante> ultimaMatricula(Estudiante estudiante) {
        if (estudiante.getId() == null) return Optional.empty();
        return matriculaRepository.findByEstudianteId(estudiante.getId()).stream()
                .filter(m -> m.getEstadoMatEst() == EstadoRegistro.A)
                .max(Comparator.comparing(MatriculaEstudiante::getId));
    }

    /** La UAP; si la BD todavia no la tiene (produccion sin seed) se crea. */
    private Institucion uap() {
        return institucionRepository.findBySiglaIgnoreCase(SIGLA_UAP).stream()
                .filter(i -> i.getEstadoInst() == EstadoRegistro.A)
                .findFirst()
                .orElseGet(() -> {
                    TipoInstitucion universidad = tipoInstitucionRepository.findByCodigo("UNIVERSIDAD").orElseGet(() -> {
                        TipoInstitucion tipo = new TipoInstitucion();
                        tipo.setCodigo("UNIVERSIDAD");
                        tipo.setNombre("Universidad");
                        return tipoInstitucionRepository.save(tipo);
                    });
                    Institucion nueva = new Institucion();
                    nueva.setTipoInstitucion(universidad);
                    nueva.setNombre("Universidad Amazonica de Pando");
                    nueva.setSigla(SIGLA_UAP);
                    nueva.setCiudad("Cobija");
                    return institucionRepository.save(nueva);
                });
    }

    /** La carrera del SIGSE en la UAP (sin importar tildes ni mayusculas); si no existe se crea. */
    private Carrera carrera(Institucion uap, String nombre) {
        String buscado = nombre == null || nombre.isBlank() ? "Sin carrera" : nombre.trim();
        return carreraRepository.findByInstitucionId(uap.getId()).stream()
                .filter(c -> c.getEstadoCarrera() == EstadoRegistro.A)
                .filter(c -> normalizar(c.getNombre()).equals(normalizar(buscado)))
                .findFirst()
                .orElseGet(() -> {
                    Carrera nueva = new Carrera();
                    nueva.setInstitucion(uap);
                    nueva.setNombre(buscado);
                    return carreraRepository.save(nueva);
                });
    }

    /** Mayusculas sin tildes ni espacios de mas: "Pérez  Ñuflo" -> "PEREZ NUFLO". */
    static String normalizar(String texto) {
        if (texto == null) return "";
        return Normalizer.normalize(texto, Normalizer.Form.NFD).replaceAll("\\p{M}", "")
                .replaceAll("\\s+", " ").trim().toUpperCase(Locale.ROOT);
    }

    private static String soloDigitos(String texto) {
        return texto.replaceAll("\\D", "");
    }
}
