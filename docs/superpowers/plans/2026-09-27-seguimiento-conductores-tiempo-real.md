# Seguimiento de conductores en tiempo real - Plan de implementacion

> **Para trabajadores agiles:** SUB-SKILL OBLIGATORIA: usar superpowers:subagent-driven-development
> (recomendado) o superpowers:executing-plans para implementar este plan tarea por tarea. Los pasos
> usan casillas (`- [ ]`) para dar seguimiento.

**Objetivo:** mapa de flota en el panel web de administracion donde el admin vea en vivo donde esta
cada conductor, con detalle y modo "Seguir", alimentado por ingesta STOMP desde el backend.

**Arquitectura:** el conductor (hoy un simulador) envia su posicion con `SEND /app/conductor/ubicacion`.
Un `@MessageMapping` valida el rol CONDUCTOR contra el token, resuelve el conductor por
`findByUsuarioId`, hace upsert en `ubicacion_conductor` y difunde un delta en
`/topic/admin/conductores`. El panel se suscribe a ese topic (solo ADMIN) y combina los deltas con
el snapshot que trae `GET /api/admin/conductores/ubicaciones`.

**Stack tecnologico:** Spring Boot 4.1.1 (WebSocket STOMP, JPA, PostGIS), Flutter Web 3.x
(`flutter_map` 8.3.2, `stomp_dart_client` 3.0.1), JUnit 6 + Mockito 5.23 en el backend, `flutter_test`
en el panel.

**Especificacion:** `docs/superpowers/specs/2026-09-27-seguimiento-conductores-tiempo-real-design.md`

## Restricciones globales

- Todo el codigo (clases, metodos, variables, rutas, mensajes) en espanol, sin tildes en el codigo ni
  emojis, igual que uniFex. Comments y javadoc en espanol.
- Respuestas HTTP con `ApiResponse<T>`; nunca exponer entidades.
- Paquete base `com.taxiuap.backend`; el dominio es `location`.
- Borrado logico con `EstadoRegistro`; el filtro de listados es siempre `estado = 'A'`.
- Entidades JPA con los nombres de tabla y columna exactos del modelo de datos.
- En el panel: iconos Font Awesome (`FaIcon`), nunca emojis. Colores de `lib/core/tema.dart`
  (`azul`, `azulClaro`, `rojo`, `exito`, `textoSuave`, `superficie`, `borde`, `azulNeblina`).
- En textos de la interfaz no usar flechas ni simbolos especiales (sale como cuadro vacio).
- El panel es solo lector: nunca publica posiciones.
- El token viaja en el frame `CONNECT` (`stompConnectHeaders`), nunca en el query string.
- Estilo de commits del repositorio: `<ambito>: <descripcion>` en minusculas y espanol.
- Rutas de verificacion: `cd backend && ./gradlew build`, `cd admin-panel && flutter analyze`,
  `cd admin-panel && flutter test`.

---

## Mapa de archivos

**Backend nuevos:**
- `location/dto/UbicacionConductorRequest.java` - posicion que envia el conductor, con rangos
  validados en su constructor compacto
- `location/dto/ConductorUbicacionResponse.java` - record del snapshot REST (con nombre y placa)
- `location/dto/PosicionConductorMensaje.java` - delta que viaja por WebSocket
- `location/service/UbicacionService.java` - `registrar` (upsert + disponibilidad) y `listarFlota`
- `location/service/ConductorUbicacionController.java` - `@MessageMapping("/conductor/ubicacion")`
- `location/service/ConductorUbicacionPublisher.java` - difunde en `/topic/admin/conductores`
- `config/InterceptorWebSocketSeguridad.java` - `ChannelInterceptor` extraido de `WebSocketConfig`
  con el gate de rol de `/topic/admin/`
- `controller/admin/ConductorUbicacionAdminController.java` - `GET /api/admin/conductores/ubicaciones`

**Backend modificados:**
- `config/WebSocketConfig.java` - delega el interceptor
- `identity/repository/ConductorRepository.java` - `findAprobadosParaFlota`
- `location/repository/UbicacionConductorRepository.java` - `findByConductorIdIn`
- `vehicle/repository/VehiculoRepository.java` - `findDeConductores`

**Backend tests:**
- `src/test/java/com/taxiuap/backend/location/dto/UbicacionConductorRequestTest.java`
- `src/test/java/com/taxiuap/backend/location/service/UbicacionServiceTest.java`
- `src/test/java/com/taxiuap/backend/location/service/ConductorUbicacionControllerTest.java`
- `src/test/java/com/taxiuap/backend/config/InterceptorWebSocketSeguridadTest.java`

**Frontend nuevos:**
- `admin-panel/lib/core/stomp/cliente_stomp.dart` - envoltura de `stomp_dart_client`
- `admin-panel/lib/modulos/flota/modelos.dart` - `ConductorEnVivo`, `DisponibilidadConductor`
- `admin-panel/lib/modulos/flota/flota_api.dart` - `listarFlota()`
- `admin-panel/lib/modulos/flota/pantalla_conductores_vivo.dart` - la pantalla
- `admin-panel/tool/simulador_conductores.dart` - simulador con 4 conexiones STOMP

**Frontend modificados:**
- `admin-panel/pubspec.yaml` - + `stomp_dart_client`
- `admin-panel/lib/core/config.dart` - + `wsUrl`
- `admin-panel/lib/core/menu.dart` - + opcion en el grupo Mapa
- `admin-panel/lib/core/rutas.dart` - + ruta
- `admin-panel/test/cliente_stomp_test.dart`
- `admin-panel/test/conductor_en_vivo_test.dart`

---

### Tarea 1: DTOs de posicion con validacion en el constructor

**Archivos:**
- Crear: `backend/src/main/java/com/taxiuap/backend/location/dto/UbicacionConductorRequest.java`
- Crear: `backend/src/main/java/com/taxiuap/backend/location/dto/ConductorUbicacionResponse.java`
- Crear: `backend/src/main/java/com/taxiuap/backend/location/dto/PosicionConductorMensaje.java`
- Testear: `backend/src/test/java/com/taxiuap/backend/location/dto/UbicacionConductorRequestTest.java`

**Interfaces:**
- Consume: nada (es la base de la que dependen las tareas 2 y 3).
- Produce:
  - `UbicacionConductorRequest(BigDecimal latitud, BigDecimal longitud, BigDecimal rumbo, BigDecimal velocidad, Disponibilidad disponibilidad)` - lanza `NegocioException` si un rango no se cumple.
  - `ConductorUbicacionResponse(Long idConductor, String nombres, String apellidos, String placa, BigDecimal calificacionPromedio, BigDecimal latitud, BigDecimal longitud, BigDecimal rumbo, BigDecimal velocidad, Disponibilidad disponibilidad, LocalDateTime actualizadoEn)`
  - `PosicionConductorMensaje(Long idConductor, BigDecimal latitud, BigDecimal longitud, BigDecimal rumbo, BigDecimal velocidad, Disponibilidad disponibilidad, LocalDateTime actualizadoEn)`

- [ ] **Paso 1: escribir el test que falla**

Crear `backend/src/test/java/com/taxiuap/backend/location/dto/UbicacionConductorRequestTest.java`:

```java
package com.taxiuap.backend.location.dto;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.shared.exception.NegocioException;

class UbicacionConductorRequestTest {

    private static BigDecimal d(String valor) {
        return new BigDecimal(valor);
    }

    @Test
    void aceptaPosicionValida() {
        UbicacionConductorRequest request = new UbicacionConductorRequest(
                d("-11.0183"), d("-68.7551"), d("92.5"), d("24.0"), Disponibilidad.DISPONIBLE);
        assertEquals(d("-11.0183"), request.latitud());
        assertEquals(Disponibilidad.DISPONIBLE, request.disponibilidad());
    }

    @Test
    void aceptaPosicionSinRumboNiVelocidad() {
        assertDoesNotThrow(() -> new UbicacionConductorRequest(
                d("-11.0183"), d("-68.7551"), null, null, null));
    }

    @Test
    void rechazaCoordenadasAusentes() {
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(null, d("-68.7551"), null, null, null));
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), null, null, null, null));
    }

    @Test
    void rechazaLatitudFueraDeRango() {
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-90.1"), d("-68.7551"), null, null, null));
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("90.1"), d("-68.7551"), null, null, null));
    }

    @Test
    void rechazaLongitudFueraDeRango() {
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), d("-180.1"), null, null, null));
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), d("180.1"), null, null, null));
    }

    @Test
    void rechazaRumboFueraDeRango() {
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), d("-68.7551"), d("360.1"), null, null));
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), d("-68.7551"), d("-0.1"), null, null));
    }

    @Test
    void rechazaVelocidadNegativa() {
        assertThrows(NegocioException.class,
                () -> new UbicacionConductorRequest(d("-11.0183"), d("-68.7551"), null, d("-1.0"), null));
    }
}
```

- [ ] **Paso 2: correr el test y verificar que falla**

Correr: `cd backend && ./gradlew test --tests '*UbicacionConductorRequestTest'`

Esperado: FALLA al compilar con `cannot find symbol: class UbicacionConductorRequest`.

- [ ] **Paso 3: implementar `UbicacionConductorRequest`**

Crear `backend/src/main/java/com/taxiuap/backend/location/dto/UbicacionConductorRequest.java`:

```java
package com.taxiuap.backend.location.dto;

import java.math.BigDecimal;

import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.shared.exception.NegocioException;

/**
 * Posicion que reporta un conductor por WebSocket.
 *
 * Los rangos se comprueban aqui y no con anotaciones de Jakarta Validation porque el canal de
 * entrada de STOMP no ejecuta el validador sobre el cuerpo del frame. Asi, ningun objeto de este
 * tipo puede existir con coordenadas invalidas, y el mensaje se rechaza al deserializarlo.
 *
 * El rumbo, la velocidad y la disponibilidad son opcionales: un conductor puede mandar solo el par
 * de coordenadas.
 */
public record UbicacionConductorRequest(
        BigDecimal latitud,
        BigDecimal longitud,
        BigDecimal rumbo,
        BigDecimal velocidad,
        Disponibilidad disponibilidad) {

    private static final BigDecimal LATITUD_MINIMA = new BigDecimal("-90");
    private static final BigDecimal LATITUD_MAXIMA = new BigDecimal("90");
    private static final BigDecimal LONGITUD_MINIMA = new BigDecimal("-180");
    private static final BigDecimal LONGITUD_MAXIMA = new BigDecimal("180");
    private static final BigDecimal CERO = BigDecimal.ZERO;
    private static final BigDecimal GRADOS_MAXIMOS = new BigDecimal("360");

    public UbicacionConductorRequest {
        exigir(latitud != null, "La posicion debe incluir la latitud");
        exigir(longitud != null, "La posicion debe incluir la longitud");
        exigir(enRango(latitud, LATITUD_MINIMA, LATITUD_MAXIMA), "La latitud debe estar entre -90 y 90");
        exigir(enRango(longitud, LONGITUD_MINIMA, LONGITUD_MAXIMA), "La longitud debe estar entre -180 y 180");
        exigir(rumbo == null || enRango(rumbo, CERO, GRADOS_MAXIMOS), "El rumbo debe estar entre 0 y 360 grados");
        exigir(velocidad == null || velocidad.compareTo(CERO) >= 0, "La velocidad no puede ser negativa");
    }

    private static boolean enRango(BigDecimal valor, BigDecimal minimo, BigDecimal maximo) {
        return valor.compareTo(minimo) >= 0 && valor.compareTo(maximo) <= 0;
    }

    private static void exigir(boolean condicion, String mensaje) {
        if (!condicion) {
            throw new NegocioException(mensaje);
        }
    }
}
```

- [ ] **Paso 4: correr el test y verificar que pasa**

Correr: `cd backend && ./gradlew test --tests '*UbicacionConductorRequestTest'`

Esperado: PASA, 7 tests.

- [ ] **Paso 5: crear los otros dos records**

Crear `backend/src/main/java/com/taxiuap/backend/location/dto/ConductorUbicacionResponse.java`:

```java
package com.taxiuap.backend.location.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.location.enums.Disponibilidad;

/**
 * Un conductor con su ultima posicion conocida, como lo necesita el mapa del panel: los datos del
 * marcador y del modal de detalle. Las coordenadas van en null cuando el conductor aun no reporto
 * su posicion; el panel lo cuenta igual pero no dibuja marcador.
 */
public record ConductorUbicacionResponse(
        Long idConductor,
        String nombres,
        String apellidos,
        String placa,
        BigDecimal calificacionPromedio,
        BigDecimal latitud,
        BigDecimal longitud,
        BigDecimal rumbo,
        BigDecimal velocidad,
        Disponibilidad disponibilidad,
        LocalDateTime actualizadoEn) {
}
```

Crear `backend/src/main/java/com/taxiuap/backend/location/dto/PosicionConductorMensaje.java`:

```java
package com.taxiuap.backend.location.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.location.enums.Disponibilidad;

/**
 * Cambio de posicion de un conductor, que es lo que viaja por WebSocket. No lleva nombre ni
 * placa: el panel ya los tiene del snapshot REST y asi el servicio no tiene que releer la persona
 * y el vehiculo en cada reporte, que llega cada 2 o 3 segundos por conductor.
 */
public record PosicionConductorMensaje(
        Long idConductor,
        BigDecimal latitud,
        BigDecimal longitud,
        BigDecimal rumbo,
        BigDecimal velocidad,
        Disponibilidad disponibilidad,
        LocalDateTime actualizadoEn) {
}
```

- [ ] **Paso 6: compilar**

Correr: `cd backend && ./gradlew compileJava`

Esperado: BUILD SUCCESSFUL.

- [ ] **Paso 7: commit**

```bash
git add backend/src/main/java/com/taxiuap/backend/location/dto backend/src/test/java/com/taxiuap/backend/location/dto
git commit -m "backend: dto de posicion de conductor validado en el constructor"
```

---

### Tarea 2: Servicio de ubicacion

**Archivos:**
- Crear: `backend/src/main/java/com/taxiuap/backend/location/service/UbicacionService.java`
- Crear: `backend/src/main/java/com/taxiuap/backend/location/service/ConductorUbicacionPublisher.java`
- Modificar: `backend/src/main/java/com/taxiuap/backend/identity/repository/ConductorRepository.java`
- Modificar: `backend/src/main/java/com/taxiuap/backend/location/repository/UbicacionConductorRepository.java`
- Modificar: `backend/src/main/java/com/taxiuap/backend/vehicle/repository/VehiculoRepository.java`
- Testear: `backend/src/test/java/com/taxiuap/backend/location/service/UbicacionServiceTest.java`

**Interfaces:**
- Consume: `UbicacionConductorRequest`, `PosicionConductorMensaje`, `ConductorUbicacionResponse`,
  `Disponibilidad` de la tarea 1.
- Produce:
  - `PosicionConductorMensaje registrar(Long idUsuario, UbicacionConductorRequest request)`
  - `List<ConductorUbicacionResponse> listarFlota()`
  - `ConductorUbicacionPublisher.publicar(PosicionConductorMensaje mensaje)`
  - `ConductorRepository.findAprobadosParaFlota(EstadoRegistro estado, SituacionAprobacion situacion)` devuelve `List<Conductor>` con usuario y persona cargados
  - `UbicacionConductorRepository.findByConductorIdIn(Collection<Long> ids)` devuelve `List<UbicacionConductor>`
  - `VehiculoRepository.findDeConductores(Collection<Long> ids, EstadoRegistro estado)` devuelve `List<Vehiculo>` con el conductor cargado

- [ ] **Paso 1: escribir el test que falla**

Crear `backend/src/test/java/com/taxiuap/backend/location/service/UbicacionServiceTest.java`:

```java
package com.taxiuap.backend.location.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.location.dto.ConductorUbicacionResponse;
import com.taxiuap.backend.location.dto.PosicionConductorMensaje;
import com.taxiuap.backend.location.dto.UbicacionConductorRequest;
import com.taxiuap.backend.location.entity.DisponibilidadConductor;
import com.taxiuap.backend.location.entity.UbicacionConductor;
import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.location.repository.DisponibilidadConductorRepository;
import com.taxiuap.backend.location.repository.UbicacionConductorRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class UbicacionServiceTest {

    private static final long ID_USUARIO = 7L;
    private static final long ID_CONDUCTOR = 3L;

    @Mock
    private ConductorRepository conductorRepository;
    @Mock
    private UbicacionConductorRepository ubicacionConductorRepository;
    @Mock
    private DisponibilidadConductorRepository disponibilidadConductorRepository;
    @Mock
    private VehiculoRepository vehiculoRepository;
    @Mock
    private ConductorUbicacionPublisher publisher;

    @InjectMocks
    private UbicacionService servicio;

    @Captor
    private ArgumentCaptor<UbicacionConductor> ubicacionCaptor;
    @Captor
    private ArgumentCaptor<DisponibilidadConductor> disponibilidadCaptor;

    private Conductor conductor;

    @BeforeEach
    void preparar() {
        conductor = new Conductor();
        conductor.setId(ID_CONDUCTOR);
        conductor.setSituacionAprobacion(SituacionAprobacion.APROBADO);
        conductor.setEstadoConductor(EstadoRegistro.A);
        conductor.setCalificacionPromedio(new BigDecimal("4.60"));
        Persona persona = new Persona();
        persona.setNombres("Ivan");
        persona.setApellidos("Chavez");
        Usuario usuario = new Usuario();
        usuario.setPersona(persona);
        conductor.setUsuario(usuario);
    }

    private UbicacionConductorRequest request(Disponibilidad disponibilidad) {
        return new UbicacionConductorRequest(
                new BigDecimal("-11.0183"), new BigDecimal("-68.7551"),
                new BigDecimal("92.5"), new BigDecimal("24.0"), disponibilidad);
    }

    @Test
    void creaLaUbicacionCuandoElConductorNoTeniaFila() {
        when(conductorRepository.findByUsuarioId(ID_USUARIO)).thenReturn(Optional.of(conductor));
        when(ubicacionConductorRepository.findByConductorId(ID_CONDUCTOR)).thenReturn(Optional.empty());
        when(ubicacionConductorRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        PosicionConductorMensaje resultado = servicio.registrar(ID_USUARIO, request(Disponibilidad.DISPONIBLE));

        assertEquals(ID_CONDUCTOR, resultado.idConductor());
        assertEquals(new BigDecimal("-11.0183"), resultado.latitud());
        assertEquals(Disponibilidad.DISPONIBLE, resultado.disponibilidad());
        verify(ubicacionConductorRepository, times(1)).save(ubicacionCaptor.capture());
        Point punto = ubicacionCaptor.getValue().getUbicacion();
        assertEquals(-11.0183, punto.getY(), 0.0001);
        assertEquals(-68.7551, punto.getX(), 0.0001);
    }

    @Test
    void actualizaLaFilaQueYaExistia() {
        UbicacionConductor existente = new UbicacionConductor();
        existente.setId(50L);
        existente.setConductor(conductor);
        when(conductorRepository.findByUsuarioId(ID_USUARIO)).thenReturn(Optional.of(conductor));
        when(ubicacionConductorRepository.findByConductorId(ID_CONDUCTOR)).thenReturn(Optional.of(existente));
        when(ubicacionConductorRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        servicio.registrar(ID_USUARIO, request(null));

        verify(ubicacionConductorRepository).save(ubicacionCaptor.capture());
        assertEquals(50L, ubicacionCaptor.getValue().getId());
    }

    @Test
    void difundeElCambioAlTopicDeAdmin() {
        when(conductorRepository.findByUsuarioId(ID_USUARIO)).thenReturn(Optional.of(conductor));
        when(ubicacionConductorRepository.findByConductorId(ID_CONDUCTOR)).thenReturn(Optional.empty());
        when(ubicacionConductorRepository.save(any())).thenAnswer(i -> i.getArgument(0));

        PosicionConductorMensaje mensaje = servicio.registrar(ID_USUARIO, request(null));

        verify(publisher).publicar(mensaje);
    }

    @Test
    void registraDisponibilidadSoloCuandoCambia() {
        when(conductorRepository.findByUsuarioId(ID_USUARIO)).thenReturn(Optional.of(conductor));
        when(ubicacionConductorRepository.findByConductorId(ID_CONDUCTOR)).thenReturn(Optional.empty());
        when(ubicacionConductorRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        DisponibilidadConductor vigente = new DisponibilidadConductor();
        vigente.setDisponibilidad(Disponibilidad.DISPONIBLE);
        when(disponibilidadConductorRepository.findFirstByConductorIdOrderByDesdeDesc(ID_CONDUCTOR))
                .thenReturn(Optional.of(vigente));

        servicio.registrar(ID_USUARIO, request(Disponibilidad.DISPONIBLE));

        verify(disponibilidadConductorRepository, never()).save(any());
    }

    @Test
    void insertaDisponibilidadCuandoEsDistinta() {
        when(conductorRepository.findByUsuarioId(ID_USUARIO)).thenReturn(Optional.of(conductor));
        when(ubicacionConductorRepository.findByConductorId(ID_CONDUCTOR)).thenReturn(Optional.empty());
        when(ubicacionConductorRepository.save(any())).thenAnswer(i -> i.getArgument(0));
        DisponibilidadConductor vigente = new DisponibilidadConductor();
        vigente.setDisponibilidad(Disponibilidad.DISPONIBLE);
        when(disponibilidadConductorRepository.findFirstByConductorIdOrderByDesdeDesc(ID_CONDUCTOR))
                .thenReturn(Optional.of(vigente));

        servicio.registrar(ID_USUARIO, request(Disponibilidad.OCUPADO));

        verify(disponibilidadConductorRepository).save(disponibilidadCaptor.capture());
        assertEquals(Disponibilidad.OCUPADO, disponibilidadCaptor.getValue().getDisponibilidad());
        assertEquals(conductor, disponibilidadCaptor.getValue().getConductor());
    }

    @Test
    void rechazaConductorNoAprobado() {
        conductor.setSituacionAprobacion(SituacionAprobacion.PENDIENTE);
        when(conductorRepository.findByUsuarioId(ID_USUARIO)).thenReturn(Optional.of(conductor));

        NegocioException e = assertThrows(NegocioException.class,
                () -> servicio.registrar(ID_USUARIO, request(null)));

        assertEquals("Solo los conductores aprobados pueden reportar su posicion", e.getMessage());
        verify(ubicacionConductorRepository, never()).save(any());
    }

    @Test
    void rechazaConductorDeBaja() {
        conductor.setEstadoConductor(EstadoRegistro.X);
        when(conductorRepository.findByUsuarioId(ID_USUARIO)).thenReturn(Optional.of(conductor));

        assertThrows(NegocioException.class, () -> servicio.registrar(ID_USUARIO, request(null)));
    }

    @Test
    void rechazaUsuarioQueNoEsConductor() {
        when(conductorRepository.findByUsuarioId(ID_USUARIO)).thenReturn(Optional.empty());

        NegocioException e = assertThrows(NegocioException.class,
                () -> servicio.registrar(ID_USUARIO, request(null)));

        assertEquals("El usuario autenticado no es un conductor", e.getMessage());
    }

    @Test
    void listaFlotaConYSinPosiciones() {
        Conductor sinPosicion = new Conductor();
        sinPosicion.setId(4L);
        sinPosicion.setSituacionAprobacion(SituacionAprobacion.APROBADO);
        sinPosicion.setEstadoConductor(EstadoRegistro.A);
        Persona otra = new Persona();
        otra.setNombres("Julia");
        otra.setApellidos("Mendez");
        Usuario usuarioOtro = new Usuario();
        usuarioOtro.setPersona(otra);
        sinPosicion.setUsuario(usuarioOtro);

        when(conductorRepository.findAprobadosParaFlota(EstadoRegistro.A, SituacionAprobacion.APROBADO))
                .thenReturn(List.of(conductor, sinPosicion));

        UbicacionConductor conPunto = new UbicacionConductor();
        conPunto.setConductor(conductor);
        conPunto.setUbicacion(crearPunto(-11.0183, -68.7551));
        conPunto.setRumbo(new BigDecimal("92.5"));
        conPunto.setVelocidad(new BigDecimal("24.0"));
        conPunto.setActualizadoEn(LocalDateTime.now());
        when(ubicacionConductorRepository.findByConductorIdIn(any())).thenReturn(List.of(conPunto));

        Vehiculo moto = new Vehiculo();
        moto.setConductor(conductor);
        moto.setPlaca("1234-ABC");
        moto.setEstadoVehiculo(EstadoRegistro.A);
        when(vehiculoRepository.findDeConductores(any(), any())).thenReturn(List.of(moto));

        when(disponibilidadConductorRepository.findFirstByConductorIdOrderByDesdeDesc(ID_CONDUCTOR))
                .thenReturn(Optional.empty());
        when(disponibilidadConductorRepository.findFirstByConductorIdOrderByDesdeDesc(4L))
                .thenReturn(Optional.of(disponibilidad(Disponibilidad.OCUPADO)));

        List<ConductorUbicacionResponse> flota = servicio.listarFlota();

        assertEquals(2, flota.size());
        assertEquals("Ivan", flota.get(0).nombres());
        assertEquals("1234-ABC", flota.get(0).placa());
        assertEquals(new BigDecimal("-11.0183"), flota.get(0).latitud());
        assertEquals(Disponibilidad.OCUPADO, flota.get(1).disponibilidad());
        assertNull(flota.get(1).latitud());
        assertNull(flota.get(1).actualizadoEn());
    }

    @Test
    void listaFlotaVaciaSinConductores() {
        when(conductorRepository.findAprobadosParaFlota(EstadoRegistro.A, SituacionAprobacion.APROBADO))
                .thenReturn(List.of());

        assertEquals(List.of(), servicio.listarFlota());
        verify(ubicacionConductorRepository, never()).findByConductorIdIn(any());
    }

    private DisponibilidadConductor disponibilidad(Disponibilidad valor) {
        DisponibilidadConductor registro = new DisponibilidadConductor();
        registro.setDisponibilidad(valor);
        return registro;
    }

    private Point crearPunto(double latitud, double longitud) {
        GeometryFactory fabrica = new GeometryFactory(new PrecisionModel(), 4326);
        return fabrica.createPoint(new Coordinate(longitud, latitud));
    }
}
```

- [ ] **Paso 2: correr el test y verificar que falla**

Correr: `cd backend && ./gradlew test --tests '*UbicacionServiceTest'`

Esperado: FALLA al compilar con `cannot find symbol: class UbicacionService` y
`cannot find symbol: class ConductorUbicacionPublisher`.

- [ ] **Paso 3: agregar las consultas de repositorio**

En `backend/src/main/java/com/taxiuap/backend/identity/repository/ConductorRepository.java`, agregar
el import de `Query` y el metodo:

```java
    /** Conductores aptos para el mapa de flota, con usuario y persona ya cargados. */
    @Query("""
            select c from Conductor c
            join fetch c.usuario u
            join fetch u.persona
            where c.estadoConductor = :estado and c.situacionAprobacion = :situacion
            order by c.id
            """)
    List<Conductor> findAprobadosParaFlota(EstadoRegistro estado, SituacionAprobacion situacion);
```

En `backend/src/main/java/com/taxiuap/backend/location/repository/UbicacionConductorRepository.java`,
agregar:

```java
    List<UbicacionConductor> findByConductorIdIn(Collection<Long> ids);
```

y el import `java.util.Collection`.

En `backend/src/main/java/com/taxiuap/backend/vehicle/repository/VehiculoRepository.java`, agregar:

```java
    /** Vehiculos de varios conductores de una sola vez, con el conductor cargado para leer su id. */
    @Query("""
            select v from Vehiculo v
            join fetch v.conductor
            where v.conductor.id in :ids and v.estadoVehiculo = :estado
            order by v.id
            """)
    List<Vehiculo> findDeConductores(Collection<Long> ids, EstadoRegistro estado);
```

y los imports de `java.util.Collection`, `org.springframework.data.jpa.repository.Query` y
`com.taxiuap.backend.shared.enums.EstadoRegistro`.

- [ ] **Paso 4: crear `ConductorUbicacionPublisher`**

Crear `backend/src/main/java/com/taxiuap/backend/location/service/ConductorUbicacionPublisher.java`:

```java
package com.taxiuap.backend.location.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

import com.taxiuap.backend.location.dto.PosicionConductorMensaje;

import lombok.RequiredArgsConstructor;

/**
 * Publicacion de la posicion de los conductores hacia el topic del panel. Mismo criterio que
 * ViajeEventPublisher: si el broker esta caido se avisa con un log y no se tumba la transaccion que
 * ya guardo la posicion.
 */
@Component
@RequiredArgsConstructor
public class ConductorUbicacionPublisher {

    private static final Logger LOG = LoggerFactory.getLogger(ConductorUbicacionPublisher.class);

    private final SimpMessagingTemplate simpMessagingTemplate;

    public void publicar(PosicionConductorMensaje mensaje) {
        try {
            simpMessagingTemplate.convertAndSend("/topic/admin/conductores", mensaje);
        } catch (Exception excepcion) {
            LOG.warn("No se pudo difundir la posicion del conductor {} por WebSocket",
                    mensaje.idConductor(), excepcion);
        }
    }
}
```

- [ ] **Paso 5: crear `UbicacionService`**

Crear `backend/src/main/java/com/taxiuap/backend/location/service/UbicacionService.java`:

```java
package com.taxiuap.backend.location.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.location.dto.ConductorUbicacionResponse;
import com.taxiuap.backend.location.dto.PosicionConductorMensaje;
import com.taxiuap.backend.location.dto.UbicacionConductorRequest;
import com.taxiuap.backend.location.entity.DisponibilidadConductor;
import com.taxiuap.backend.location.entity.UbicacionConductor;
import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.location.repository.DisponibilidadConductorRepository;
import com.taxiuap.backend.location.repository.UbicacionConductorRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

import lombok.RequiredArgsConstructor;

/**
 * Posicion de los conductores en tiempo real: la que reporta el conductor y la que necesita el
 * mapa del panel para pintar la flota.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UbicacionService {

    private static final GeometryFactory FABRICA_GEOMETRIA =
            new GeometryFactory(new PrecisionModel(), 4326);

    private final ConductorRepository conductorRepository;
    private final UbicacionConductorRepository ubicacionConductorRepository;
    private final DisponibilidadConductorRepository disponibilidadConductorRepository;
    private final VehiculoRepository vehiculoRepository;
    private final ConductorUbicacionPublisher publisher;

    /**
     * Guarda la posicion que reporta un conductor y la difunde a los administradores.
     *
     * El id del conductor sale del id de usuario del token, nunca del cuerpo del mensaje, para que
     * un conductor no pueda reportar la posicion de otro.
     */
    @Transactional
    public PosicionConductorMensaje registrar(Long idUsuario, UbicacionConductorRequest request) {
        Conductor conductor = obtenerConductorAprobado(idUsuario);
        registrarDisponibilidad(conductor, request.disponibilidad());

        UbicacionConductor ubicacion = ubicacionConductorRepository.findByConductorId(conductor.getId())
                .orElseGet(UbicacionConductor::new);
        ubicacion.setConductor(conductor);
        ubicacion.setUbicacion(crearPunto(request.latitud(), request.longitud()));
        ubicacion.setRumbo(request.rumbo());
        ubicacion.setVelocidad(request.velocidad());
        ubicacion.setActualizadoEn(LocalDateTime.now());
        ubicacion.setEstadoUbicacionConductor(EstadoRegistro.A);

        PosicionConductorMensaje mensaje = aMensaje(conductor, ubicacionConductorRepository.save(ubicacion));
        publisher.publicar(mensaje);
        return mensaje;
    }

    /**
     * Flota para el mapa: todos los conductores aprobados y activos, tengan o no posicion. Los que
     * aun no reportaron salen con las coordenadas en null, para que el panel los cuente sin
     * dibujarles marcador.
     */
    public List<ConductorUbicacionResponse> listarFlota() {
        List<Conductor> conductores = conductorRepository.findAprobadosParaFlota(
                EstadoRegistro.A, SituacionAprobacion.APROBADO);
        if (conductores.isEmpty()) {
            return List.of();
        }
        List<Long> ids = conductores.stream().map(Conductor::getId).toList();

        Map<Long, UbicacionConductor> ubicaciones = ubicacionConductorRepository.findByConductorIdIn(ids)
                .stream()
                .collect(Collectors.toMap(u -> u.getConductor().getId(), Function.identity()));
        Map<Long, String> placas = new HashMap<>();
        for (Vehiculo vehiculo : vehiculoRepository.findDeConductores(ids, EstadoRegistro.A)) {
            placas.putIfAbsent(vehiculo.getConductor().getId(), vehiculo.getPlaca());
        }

        return conductores.stream()
                .map(conductor -> aResponse(conductor, ubicaciones.get(conductor.getId()),
                        placas.get(conductor.getId()), disponibilidadActual(conductor.getId())))
                .toList();
    }

    private Conductor obtenerConductorAprobado(Long idUsuario) {
        Conductor conductor = conductorRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario autenticado no es un conductor"));
        if (conductor.getEstadoConductor() != EstadoRegistro.A) {
            throw new NegocioException("El conductor esta dado de baja");
        }
        if (conductor.getSituacionAprobacion() != SituacionAprobacion.APROBADO) {
            throw new NegocioException("Solo los conductores aprobados pueden reportar su posicion");
        }
        return conductor;
    }

    /**
     * La tabla disponibilidad_conductor es historial: si el valor cambio se inserta una fila nueva
     * y la anterior se conserva. Si no vino disponibilidad o es la misma de la vigente, no se
     * escribe nada.
     */
    private void registrarDisponibilidad(Conductor conductor, Disponibilidad nueva) {
        if (nueva == null || nueva == disponibilidadActual(conductor.getId())) {
            return;
        }
        DisponibilidadConductor registro = new DisponibilidadConductor();
        registro.setConductor(conductor);
        registro.setDisponibilidad(nueva);
        registro.setDesde(LocalDateTime.now());
        registro.setEstadoDisponibilidadConductor(EstadoRegistro.A);
        disponibilidadConductorRepository.save(registro);
    }

    private Disponibilidad disponibilidadActual(Long idConductor) {
        return disponibilidadConductorRepository.findFirstByConductorIdOrderByDesdeDesc(idConductor)
                .map(DisponibilidadConductor::getDisponibilidad)
                .orElse(Disponibilidad.DESCONECTADO);
    }

    private PosicionConductorMensaje aMensaje(Conductor conductor, UbicacionConductor ubicacion) {
        return new PosicionConductorMensaje(
                conductor.getId(),
                coordenada(ubicacion, true),
                coordenada(ubicacion, false),
                ubicacion.getRumbo(),
                ubicacion.getVelocidad(),
                disponibilidadActual(conductor.getId()),
                ubicacion.getActualizadoEn());
    }

    private ConductorUbicacionResponse aResponse(Conductor conductor, UbicacionConductor ubicacion,
            String placa, Disponibilidad disponibilidad) {
        return new ConductorUbicacionResponse(
                conductor.getId(),
                conductor.getUsuario().getPersona().getNombres(),
                conductor.getUsuario().getPersona().getApellidos(),
                placa,
                conductor.getCalificacionPromedio(),
                coordenada(ubicacion, true),
                coordenada(ubicacion, false),
                ubicacion != null ? ubicacion.getRumbo() : null,
                ubicacion != null ? ubicacion.getVelocidad() : null,
                disponibilidad,
                ubicacion != null ? ubicacion.getActualizadoEn() : null);
    }

    /** Coordenada de la ultima posicion: [true] latitude, [false] longitud, null si no hay. */
    private BigDecimal coordenada(UbicacionConductor ubicacion, boolean latitud) {
        if (ubicacion == null || ubicacion.getUbicacion() == null) {
            return null;
        }
        Point punto = ubicacion.getUbicacion();
        return BigDecimal.valueOf(latitud ? punto.getY() : punto.getX());
    }

    private Point crearPunto(BigDecimal latitud, BigDecimal longitud) {
        return FABRICA_GEOMETRIA.createPoint(
                new Coordinate(longitud.doubleValue(), latitud.doubleValue()));
    }
}
```

- [ ] **Paso 6: correr el test y verificar que pasa**

Correr: `cd backend && ./gradlew test --tests '*UbicacionServiceTest'`

Esperado: PASA, 10 tests.

- [ ] **Paso 7: compilar todo**

Correr: `cd backend && ./gradlew build`

Esperado: BUILD SUCCESSFUL y los 17 tests (7 de la tarea 1, 10 de esta) en verde.

- [ ] **Paso 8: commit**

```bash
git add backend/src/main/java/com/taxiuap/backend/location backend/src/main/java/com/taxiuap/backend/identity/repository/ConductorRepository.java backend/src/main/java/com/taxiuap/backend/vehicle/repository/VehiculoRepository.java backend/src/test/java/com/taxiuap/backend/location
git commit -m "backend: servicio de ubicacion de conductores con upsert y listado de flota"
```

---

### Tarea 3: Ingesta STOMP y endpoint de snapshot

**Archivos:**
- Crear: `backend/src/main/java/com/taxiuap/backend/location/service/ConductorUbicacionController.java`
- Crear: `backend/src/main/java/com/taxiuap/backend/controller/admin/ConductorUbicacionAdminController.java`
- Testear: `backend/src/test/java/com/taxiuap/backend/location/service/ConductorUbicacionControllerTest.java`

**Interfaces:**
- Consume: `UbicacionService.registrar(Long, UbicacionConductorRequest)` y `listarFlota()` de la
  tarea 2.
- Produce: destino `SEND /app/conductor/ubicacion` (cuerpo `UbicacionConductorRequest`) y endpoint
  `GET /api/admin/conductores/ubicaciones` que devuelve
  `ApiResponse<List<ConductorUbicacionResponse>>`.

- [ ] **Paso 1: escribir el test que falla**

Crear `backend/src/test/java/com/taxiuap/backend/location/service/ConductorUbicacionControllerTest.java`:

```java
package com.taxiuap.backend.location.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.math.BigDecimal;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageBuilder;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.location.dto.UbicacionConductorRequest;
import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.shared.exception.NegocioException;

@ExtendWith(MockitoExtension.class)
class ConductorUbicacionControllerTest {

    @Mock
    private UbicacionService ubicacionService;

    @InjectMocks
    private ConductorUbicacionController controller;

    private static final long ID_USUARIO = 7L;

    private Message<UbicacionConductorRequest> mensaje(String rol) {
        JwtUser usuario = new JwtUser(ID_USUARIO, "conductor1", rol);
        UsernamePasswordAuthenticationToken principal = new UsernamePasswordAuthenticationToken(
                usuario, null, List.of(new SimpleGrantedAuthority("ROLE_" + rol)));
        return MessageBuilder.withPayload(new UbicacionConductorRequest(
                        new BigDecimal("-11.0183"), new BigDecimal("-68.7551"),
                        null, null, Disponibilidad.DISPONIBLE))
                .setHeader(SimpMessageHeaderAccessor.SIMP_USER_HEADER_NAME, principal)
                .build();
    }

    @Test
    void registraLaPosicionDelConductorDelToken() {
        Message<UbicacionConductorRequest> mensaje = mensaje("CONDUCTOR");

        controller.recibir(mensaje);

        verify(ubicacionService).registrar(eq(ID_USUARIO), any(UbicacionConductorRequest.class));
    }

    @Test
    void rechazaUnAdministrador() {
        NegocioException e = assertThrows(NegocioException.class, () -> controller.recibir(mensaje("ADMIN")));

        assertEquals("Solo un conductor autenticado puede reportar su posicion", e.getMessage());
        verify(ubicacionService, never()).registrar(eq(ID_USUARIO), any());
    }

    @Test
    void rechazaUnPasajero() {
        assertThrows(NegocioException.class, () -> controller.recibir(mensaje("PASAJERO")));
        verify(ubicacionService, never()).registrar(eq(ID_USUARIO), any());
    }

    @Test
    void rechazaUnFrameSinUsuario() {
        Message<UbicacionConductorRequest> sinUsuario = MessageBuilder
                .withPayload(new UbicacionConductorRequest(
                        new BigDecimal("-11.0183"), new BigDecimal("-68.7551"), null, null, null))
                .build();

        assertThrows(NegocioException.class, () -> controller.recibir(sinUsuario));
    }
}
```

- [ ] **Paso 2: correr el test y verificar que falla**
Correr: `cd backend && ./gradlew test --tests '*ConductorUbicacionControllerTest'`

Esperado: FALLA al compilar con `cannot find symbol: class ConductorUbicacionController`.

- [ ] **Paso 3: crear el controller de ingesta**

Crear `backend/src/main/java/com/taxiuap/backend/location/service/ConductorUbicacionController.java`:

```java
package com.taxiuap.backend.location.service;

import org.springframework.messaging.Message;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.location.dto.UbicacionConductorRequest;
import com.taxiuap.backend.shared.exception.NegocioException;

import lombok.RequiredArgsConstructor;

/**
 * Entrada de la posicion de los conductores: SEND /app/conductor/ubicacion.
 *
 * El conductor sale del principal del frame, que el interceptor de seguridad deja como JwtUser con
 * el rol del token. El cuerpo del mensaje solo trae coordenadas, de modo que un conductor no puede
 * reportar la posicion de otro. Si el rol no es CONDUCTOR se lanza NegocioException.
 */
@RestController
@RequiredArgsConstructor
public class ConductorUbicacionController {

    private final UbicacionService ubicacionService;

    @MessageMapping("/conductor/ubicacion")
    public void recibir(Message<UbicacionConductorRequest> mensaje) {
        Object principal = SimpMessageHeaderAccessor.wrap(mensaje).getUser();
        if (!(principal instanceof JwtUser usuario)) {
            throw new NegocioException("El frame no tiene un conductor autenticado");
        }
        if (!RolSistema.CONDUCTOR.getCodigo().equals(usuario.rol())) {
            throw new NegocioException("Solo un conductor autenticado puede reportar su posicion");
        }
        ubicacionService.registrar(usuario.idUsuario(), mensaje.getPayload());
    }
}
```

- [ ] **Paso 4: crear el endpoint de snapshot**

Crear `backend/src/main/java/com/taxiuap/backend/controller/admin/ConductorUbicacionAdminController.java`:

```java
package com.taxiuap.backend.controller.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.taxiuap.backend.location.dto.ConductorUbicacionResponse;
import com.taxiuap.backend.location.service.UbicacionService;
import com.taxiuap.backend.shared.response.ApiResponse;

import lombok.RequiredArgsConstructor;

/** Posicion de los conductores para el mapa de flota del panel. */
@RestController
@RequestMapping("/api/admin/conductores/ubicaciones")
@RequiredArgsConstructor
public class ConductorUbicacionAdminController {

    private final UbicacionService ubicacionService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<ConductorUbicacionResponse>>> listar() {
        return ResponseEntity.ok(ApiResponse.exito(ubicacionService.listarFlota()));
    }
}
```

- [ ] **Paso 5: correr el test y verificar que pasa**

Correr: `cd backend && ./gradlew test --tests '*ConductorUbicacionControllerTest'`

Esperado: PASA, 4 tests.

- [ ] **Paso 6: compilar**

Correr: `cd backend && ./gradlew build`

Esperado: BUILD SUCCESSFUL.

- [ ] **Paso 7: commit**

```bash
git add backend/src/main/java/com/taxiuap/backend/location/service/ConductorUbicacionController.java backend/src/main/java/com/taxiuap/backend/controller/admin/ConductorUbicacionAdminController.java backend/src/test/java/com/taxiuap/backend/location/service/ConductorUbicacionControllerTest.java
git commit -m "backend: ingesta stomp de la posicion del conductor y endpoint de flota"
```

---

### Tarea 4: Gate de rol del topic de administradores

**Archivos:**
- Crear: `backend/src/main/java/com/taxiuap/backend/config/InterceptorWebSocketSeguridad.java`
- Modificar: `backend/src/main/java/com/taxiuap/backend/config/WebSocketConfig.java:82-119`
- Testear: `backend/src/test/java/com/taxiuap/backend/config/InterceptorWebSocketSeguridadTest.java`

**Interfaces:**
- Consume: `JwtUser` y `RolSistema`.
- Produce: `InterceptorWebSocketSeguridad implements ChannelInterceptor`, con
  `Message<?> preSend(Message<?> mensaje, MessageChannel canal)`. Un `SUBSCRIBE` cuyo destino
  empieza por `/topic/admin/` exige `ROLE_ADMIN`.

**Por que se extrae:** hoy el interceptor es una clase anonima dentro de `WebSocketConfig`, y el
gate de rol es el control de seguridad nuevo de esta funcionalidad. Sacar su propia clase lo deja
testeable sin levantar el contexto de Spring y deja `WebSocketConfig` con su unica responsabilidad,
que es el broker y el endpoint.

- [ ] **Paso 1: escribir el test que falla**

Crear `backend/src/test/java/com/taxiuap/backend/config/InterceptorWebSocketSeguridadTest.java`:

```java
package com.taxiuap.backend.config;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import com.taxiuap.backend.config.security.JwtUser;

class InterceptorWebSocketSeguridadTest {

    private final InterceptorWebSocketSeguridad interceptor = new InterceptorWebSocketSeguridad(null);
    private final MessageChannel canal = mock(MessageChannel.class);

    private Message<byte[]> frame(StompCommand comando, String destino, String rol) {
        StompHeaderAccessor acc = StompHeaderAccessor.create(comando);
        acc.setDestination(destino);
        acc.setUser(new UsernamePasswordAuthenticationToken(
                new JwtUser(1L, "usuario", rol), null, List.of(new SimpleGrantedAuthority("ROLE_" + rol))));
        acc.setLeaveMutable(true);
        return MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());
    }

    @Test
    void elAdminPuedeSuscribirseAlTopicDeConductores() {
        assertDoesNotThrow(() -> interceptor.preSend(
                frame(StompCommand.SUBSCRIBE, "/topic/admin/conductores", "ADMIN"), canal));
    }

    @Test
    void unConductorNoPuedeSuscribirseAlTopicDeConductores() {
        assertThrows(MessagingException.class, () -> interceptor.preSend(
                frame(StompCommand.SUBSCRIBE, "/topic/admin/conductores", "CONDUCTOR"), canal));
    }

    @Test
    void unTopicNormalLoPuedeVerCualquieraAutenticado() {
        assertDoesNotThrow(() -> interceptor.preSend(
                frame(StompCommand.SUBSCRIBE, "/topic/solicitudes", "CONDUCTOR"), canal));
    }

    @Test
    void unSuscripcionSinUsuarioSeRechaza() {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        acc.setDestination("/topic/solicitudes");
        acc.setLeaveMutable(true);
        Message<byte[]> mensaje = MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());

        assertThrows(MessagingException.class, () -> interceptor.preSend(mensaje, canal));
    }
}
```

- [ ] **Paso 2: correr el test y verificar que falla**

Correr: `cd backend && ./gradlew test --tests '*InterceptorWebSocketSeguridadTest'`

Esperado: FALLA al compilar con `cannot find symbol: class InterceptorWebSocketSeguridad`.

- [ ] **Paso 3: crear el interceptor**

Crear `backend/src/main/java/com/taxiuap/backend/config/InterceptorWebSocketSeguridad.java`:

```java
package com.taxiuap.backend.config;

import java.util.List;

import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import com.taxiuap.backend.config.security.JwtService;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.config.security.TipoToken;

import lombok.RequiredArgsConstructor;

/**
 * Autentica y autoriza el trafico de WebSocket.
 *
 * La autenticacion va en el frame CONNECT y no en el handshake HTTP porque la API WebSocket del
 * navegador no permite agregar cabeceras propias, pero el frame CONNECT si lleva las cabeceras
 * nativas que el cliente STOMP le pasa en connectHeaders.
 *
 * Los destinos que empiezan por /topic/admin/ son solo para administradores: se rechaza la
 * suscripcion de cualquiera con otro rol, aunque tenga un token valido. El resto de topics sigue
 * abierto a cualquier usuario autenticado.
 */
@RequiredArgsConstructor
public class InterceptorWebSocketSeguridad implements ChannelInterceptor {

    private static final String PREFIJO_ADMIN = "/topic/admin/";
    private static final String AUTORIDAD_ADMIN = "ROLE_" + RolSistema.ADMIN.getCodigo();

    private final JwtService jwtService;

    @Override
    public Message<?> preSend(Message<?> mensaje, MessageChannel canal) {
        StompHeaderAccessor acc = MessageHeaderAccessor.getAccessor(mensaje, StompHeaderAccessor.class);
        if (acc == null || acc.getCommand() == null) {
            return mensaje;
        }
        if (StompCommand.CONNECT.equals(acc.getCommand())) {
            autenticar(acc);
        } else if (StompCommand.SUBSCRIBE.equals(acc.getCommand())) {
            exigirUsuario(acc);
            exigirAdminSiCorresponde(acc);
        } else if (StompCommand.SEND.equals(acc.getCommand())) {
            exigirUsuario(acc);
        }
        return mensaje;
    }

    private void autenticar(StompHeaderAccessor acc) {
        String cabecera = acc.getFirstNativeHeader("Authorization");
        if (cabecera == null || !cabecera.startsWith("Bearer ")) {
            throw new MessagingException("Cabecera Authorization ausente o mal formada en el CONNECT");
        }
        try {
            JwtUser usuario = jwtService.validar(cabecera.substring(7), TipoToken.ACCESO);
            acc.setUser(new UsernamePasswordAuthenticationToken(
                    usuario, null, List.of(new SimpleGrantedAuthority("ROLE_" + usuario.rol()))));
        } catch (Exception e) {
            throw new MessagingException("Token invalido o expirado");
        }
    }

    private void exigirUsuario(StompHeaderAccessor acc) {
        if (acc.getUser() == null) {
            throw new MessagingException("Se requiere autenticacion para " + acc.getCommand());
        }
    }

    private void exigirAdminSiCorresponde(StompHeaderAccessor acc) {
        String destino = acc.getDestination();
        if (destino == null || !destino.startsWith(PREFIJO_ADMIN)) {
            return;
        }
        boolean esAdmin = acc.getUser().getAuthorities().stream()
                .anyMatch(autoridad -> AUTORIDAD_ADMIN.equals(autoridad.getAuthority()));
        if (!esAdmin) {
            throw new MessagingException("El destino " + destino + " es solo para administradores");
        }
    }
}
```

- [ ] **Paso 4: correr el test y verificar que pasa**

Correr: `cd backend && ./gradlew test --tests '*InterceptorWebSocketSeguridadTest'`

Esperado: PASA, 4 tests.

- [ ] **Paso 5: delegar desde `WebSocketConfig`**

En `backend/src/main/java/com/taxiuap/backend/config/WebSocketConfig.java`, reemplazar el bloque
`configureClientInboundChannel` (lineas 81 a 99) y borrar los metodos privados `autenticar` y
`exigirUsuario` (lineas 101 a 119) por esto:

```java
    /**
     * La autenticacion y el gate de rol viven en InterceptorWebSocketSeguridad, que tiene sus
     * propias pruebas.
     */
    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new InterceptorWebSocketSeguridad(jwtService));
    }
```

Borrar de los imports los que quedaron sin uso: `MessagingException`, `ChannelInterceptor`,
`StompCommand`, `StompHeaderAccessor`, `MessageHeaderAccessor`, `JwtUser`, `TipoToken`,
`SimpleGrantedAuthority`, `UsernamePasswordAuthenticationToken` y `java.util.List`. Dejarlos
`Message`, `MessageChannel`, `ChannelRegistration`, `MessageBrokerRegistry`, `StompEndpointRegistry`
y `WebSocketMessageBrokerConfigurer`.

- [ ] **Paso 6: compilar y correr todos los tests**

Correr: `cd backend && ./gradlew build`

Esperado: BUILD SUCCESSFUL y 21 tests en verde (7 + 10 + 4).

- [ ] **Paso 7: commit**

```bash
git add backend/src/main/java/com/taxiuap/backend/config backend/src/test/java/com/taxiuap/backend/config
git commit -m "backend: gate de administrador para suscribirse al topic de conductores"
```

---

### Tarea 5: Cliente STOMP del panel

**Archivos:**
- Modificar: `admin-panel/pubspec.yaml`
- Modificar: `admin-panel/lib/core/config.dart`
- Crear: `admin-panel/lib/core/stomp/cliente_stomp.dart`
- Testear: `admin-panel/test/cliente_stomp_test.dart`

**Interfaces:**
- Consume: nada del backend; solo el token de `Sesion.tokenAcceso`.
- Produce:
  - `Config.wsUrl` (String, derivado de `Config.apiUrl`)
  - `enum EstadoWs { desconectado, conectando, conectado, reconectando }`
  - `Map<String, dynamic> decodificarMensaje(String? body, List<int>? binario)`
  - `class ClienteStomp { ClienteStomp({required String url, required String token, required String destino}); Stream<Map<String,dynamic>> get mensajes; ValueNotifier<EstadoWs> get estado; void iniciar(); void detener(); void enviar(String destino, Map<String,dynamic> cuerpo); }`

- [ ] **Paso 1: escribir el test que falla**

Crear `admin-panel/test/cliente_stomp_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_admin/core/stomp/cliente_stomp.dart';

void main() {
  group('decodificarMensaje', () {
    test('lee un cuerpo json', () {
      final mapa = decodificarMensaje('{"idConductor":3,"rumbo":92.5}', null);
      expect(mapa['idConductor'], 3);
      expect(mapa['rumbo'], 92.5);
    });

    test('lee un frame binario en utf8', () {
      // Sin content-type el parser del cliente deja el body en null y pasa los bytes aqui.
      final bytes = '{"idConductor":3}'.codeUnits;
      expect(decodificarMensaje(null, bytes)['idConductor'], 3);
    });

    test('devuelve vacio cuando no hay nada que leer', () {
      expect(decodificarMensaje(null, null), isEmpty);
      expect(decodificarMensaje('', null), isEmpty);
    });
  });
}
```

- [ ] **Paso 2: correr el test y verificar que falla**

Correr: `cd admin-panel && flutter test test/cliente_stomp_test.dart`

Esperado: FALLA con `Target of URI doesn't exist: 'package:taxiuap_admin/core/stomp/cliente_stomp.dart'`.

- [ ] **Paso 3: agregar la dependencia**

En `admin-panel/pubspec.yaml`, dentro de `dependencies`, junto a `flutter_map` y `latlong2`, agregar:

```yaml
  stomp_dart_client: ^3.0.1
```

Correr: `cd admin-panel && flutter pub get`

Esperado: resuelve `stomp_dart_client 3.0.1` sin conflictos.

- [ ] **Paso 4: agregar `Config.wsUrl`**

En `admin-panel/lib/core/config.dart`, reemplazar el archivo por:

```dart
/// Configuracion de la app. La URL del backend se puede cambiar al compilar con
/// --dart-define=API_URL=https://servidor
class Config {
  static const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

  /// Rol que puede entrar al panel.
  static const String rolAdmin = 'ADMIN';

  /// Endpoint del WebSocket STOMP, derivado de [apiUrl]: el mismo servidor con el esquema de
  /// WebSocket. El token viaja en el frame CONNECT, nunca en esta URL.
  static String get wsUrl => wsUrlDesde(apiUrl);
}

/// Convierte la URL del API en la del WebSocket. Es una funcion suelta y no un getter porque
/// [Config.apiUrl] viene de una constante de compilacion y no se puede cambiar en una prueba.
String wsUrlDesde(String apiUrl) {
  if (apiUrl.startsWith('https://')) return apiUrl.replaceFirst('https://', 'wss://');
  if (apiUrl.startsWith('http://')) return apiUrl.replaceFirst('http://', 'ws://');
  return apiUrl;
}
```

- [ ] **Paso 5: crear `cliente_stomp.dart`**

Crear `admin-panel/lib/core/stomp/cliente_stomp.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

/// Estado de la conexion STOMP, para que la interfaz pueda avisar al administrador.
enum EstadoWs { desconectado, conectando, conectado, reconectando }

/// Lee un frame STOMP. El parser del cliente trata un frame sin content-type como binario y deja
/// body en null, asi que hay que leer las dos formas.
Map<String, dynamic> decodificarMensaje(String? body, List<int>? binario) {
  final texto = body ?? (binario != null ? utf8.decode(binario) : null);
  if (texto == null || texto.isEmpty) return const {};
  return jsonDecode(texto) as Map<String, dynamic>;
}

/// Cliente STOMP del panel: una conexion, una suscripcion, con reconexion.
///
/// El token va en [StompConfig.stompConnectHeaders], que se escribe dentro del frame CONNECT como
/// texto. El otro parametro, webSocketConnectHeaders, no sirve en navegador: el navegador no
/// permite cabeceras propias en el handshake, asi que el paquete las descarta. Por eso el backend
/// lee el token de la cabecera nativa del frame CONNECT.
///
/// Los heart-beat van en 10 segundos, que es lo que declara setHeartbeatValue en WebSocketConfig.
class ClienteStomp {
  ClienteStomp({required this.url, required this.token, required this.destino});

  final String url;
  final String token;
  final String destino;

  final _mensajes = StreamController<Map<String, dynamic>>.broadcast();
  final _estado = ValueNotifier<EstadoWs>(EstadoWs.desconectado);

  late final StompClient _cliente = StompClient(
    config: StompConfig(
      url: url,
      reconnectDelay: const Duration(seconds: 5),
      heartbeatIncoming: const Duration(seconds: 10),
      heartbeatOutgoing: const Duration(seconds: 10),
      connectionTimeout: const Duration(seconds: 10),
      stompConnectHeaders: {'Authorization': 'Bearer $token'},
      onConnect: _alConectar,
      onStompError: (frame) => _estado.value = EstadoWs.reconectando,
      onWebSocketError: (e) => _estado.value = EstadoWs.reconectando,
      onWebSocketDone: _alCerrar,
    ),
  );

  /// Mensajes que llegan del topic al que se esta suscrito.
  Stream<Map<String, dynamic>> get mensajes => _mensajes.stream;

  /// Estado de la conexion, para la pastilla de la interfaz.
  ValueNotifier<EstadoWs> get estado => _estado;

  bool get conectado => _cliente.connected;

  void iniciar() {
    _estado.value = EstadoWs.conectando;
    _cliente.activate();
  }

  void detener() {
    _cliente.deactivate();
    _estado.value = EstadoWs.desconectado;
  }

  /// Envia un frame SEND. El content-type es obligatorio: sin el, el parser del propio cliente
  /// trataria el cuerpo como binario.
  void enviar(String destinoEnvio, Map<String, dynamic> cuerpo) {
    _cliente.send(
      destination: destinoEnvio,
      headers: {'content-type': 'application/json;charset=utf-8'},
      body: jsonEncode(cuerpo),
    );
  }

  void _alConectar(StompFrame frame) {
    _estado.value = EstadoWs.conectado;
    _cliente.subscribe(
      destination: destino,
      callback: (frame) {
        final mensaje = decodificarMensaje(frame.body, frame.binaryBody);
        if (mensaje.isNotEmpty) _mensajes.add(mensaje);
      },
    );
  }

  void _alCerrar() {
    if (!_estado.disposed) _estado.value = EstadoWs.desconectado;
  }

  /// Cierra la conexion y libera los flujos. La pantalla la llama en su dispose.
  Future<void> dispose() async {
    _cliente.deactivate();
    _estado.dispose();
    await _mensajes.close();
  }
}
```

- [ ] **Paso 6: correr el test y verificar que pasa**

Correr: `cd admin-panel && flutter test test/cliente_stomp_test.dart`

Esperado: PASA, 3 tests.

- [ ] **Paso 7: agregar el test de `wsUrlDesde`**

Agregar a `admin-panel/test/cliente_stomp_test.dart`, con el import
`import 'package:taxiuap_admin/core/config.dart';`, un grupo antes del de `decodificarMensaje`:

```dart
  group('wsUrlDesde', () {
    test('http pasa a ws', () {
      expect(wsUrlDesde('http://localhost:8080'), 'ws://localhost:8080');
    });

    test('https pasa a wss', () {
      expect(wsUrlDesde('https://api.taxiuap.bo'), 'wss://api.taxiuap.bo');
    });

    test('una url sin esquema se deja como esta', () {
      expect(wsUrlDesde('localhost:8080'), 'localhost:8080');
    });
  });
```

Correr: `cd admin-panel && flutter test test/cliente_stomp_test.dart`

Esperado: PASA, 6 tests.

- [ ] **Paso 8: analizar**

Correr: `cd admin-panel && flutter analyze`

Esperado: `No issues found!`.

- [ ] **Paso 9: commit**

```bash
git add admin-panel/pubspec.yaml admin-panel/pubspec.lock admin-panel/lib/core/config.dart admin-panel/lib/core/stomp admin-panel/test
git commit -m "panel admin: cliente stomp con token en el frame connect"
```

---

### Tarea 6: Modelo y api de la flota

**Archivos:**
- Crear: `admin-panel/lib/modulos/flota/modelos.dart`
- Crear: `admin-panel/lib/modulos/flota/flota_api.dart`
- Testear: `admin-panel/test/conductor_en_vivo_test.dart`

**Interfaces:**
- Consume: `ClienteApi` de `lib/core/cliente_api.dart`, `Formato` de `lib/core/formato.dart`.
- Produce:
  - `enum DisponibilidadConductor { disponible, ocupado, desconectado }`
  - `class ConductorEnVivo { final int idConductor; final String nombres; final String apellidos; final String placa; final double? calificacion; final double? latitud; final double? longitud; final double? rumbo; final double? velocidad; final DisponibilidadConductor disponibilidad; final DateTime? actualizadoEn; String get nombreCompleto; bool get tienePosicion; bool esSinSenal(DateTime ahora); ConductorEnVivo aplicarPosicion({...}); factory ConductorEnVivo.desdeJson(Map<String,dynamic> json); factory ConductorEnVivo.desdeDelta(Map<String,dynamic> json, ConductorEnVivo anterior); }`
  - `class FlotaApi { FlotaApi(ClienteApi api); Future<List<ConductorEnVivo>> listarFlota(); }`

- [ ] **Paso 1: escribir el test que falla**

Crear `admin-panel/test/conductor_en_vivo_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_admin/modulos/flota/modelos.dart';

Map<String, dynamic> snapshot({
  double? latitud = -11.0183,
  double? longitud = -68.7551,
  String disponibilidad = 'DISPONIBLE',
  String? actualizadoEn = '2026-09-27T18:40:11',
}) {
  return {
    'idConductor': 3,
    'nombres': 'Ivan',
    'apellidos': 'Chavez',
    'placa': '1234-ABC',
    'calificacionPromedio': 4.6,
    'latitud': latitud,
    'longitud': longitud,
    'rumbo': 92.5,
    'velocidad': 24.0,
    'disponibilidad': disponibilidad,
    'actualizadoEn': actualizadoEn,
  };
}

void main() {
  group('ConductorEnVivo.desdeJson', () {
    test('lee el snapshot completo', () {
      final c = ConductorEnVivo.desdeJson(snapshot());
      expect(c.idConductor, 3);
      expect(c.nombreCompleto, 'Ivan Chavez');
      expect(c.placa, '1234-ABC');
      expect(c.calificacion, 4.6);
      expect(c.disponibilidad, DisponibilidadConductor.disponible);
      expect(c.tienePosicion, isTrue);
    });

    test('un conductor sin posicion no tiene coordenadas', () {
      final c = ConductorEnVivo.desdeJson(snapshot(latitud: null, longitud: null, actualizadoEn: null));
      expect(c.tienePosicion, isFalse);
      expect(c.latitud, isNull);
      expect(c.actualizadoEn, isNull);
    });
  });

  group('esSinSenal', () {
    test('no es sin senal dentro de la ventana', () {
      final c = ConductorEnVivo.desdeJson(snapshot());
      expect(c.esSinSenal(DateTime.parse('2026-09-27T18:40:30')), isFalse);
    });

    test('es sin senal despues de 30 segundos', () {
      final c = ConductorEnVivo.desdeJson(snapshot());
      expect(c.esSinSenal(DateTime.parse('2026-09-27T18:40:41')), isTrue);
    });

    test('sin posicion es sin senal', () {
      final c = ConductorEnVivo.desdeJson(snapshot(latitud: null, longitud: null));
      expect(c.esSinSenal(DateTime.parse('2026-09-27T18:40:00')), isTrue);
    });
  });

  group('desdeDelta', () {
    test('conserva nombre y placa del snapshot', () {
      final base = ConductorEnVivo.desdeJson(snapshot());
      final actualizado = ConductorEnVivo.desdeDelta({
        'idConductor': 3,
        'latitud': -11.0300,
        'longitud': -68.7700,
        'rumbo': 10.0,
        'velocidad': 30.0,
        'disponibilidad': 'OCUPADO',
        'actualizadoEn': '2026-09-27T18:45:00',
      }, base);

      expect(actualizado.latitud, -11.0300);
      expect(actualizado.disponibilidad, DisponibilidadConductor.ocupado);
      expect(actualizado.placa, '1234-ABC');
      expect(actualizado.nombreCompleto, 'Ivan Chavez');
    });
  });
}
```

- [ ] **Paso 2: correr el test y verificar que falla**

Correr: `cd admin-panel && flutter test test/conductor_en_vivo_test.dart`

Esperado: FALLA con `Target of URI doesn't exist: 'package:taxiuap_admin/modulos/flota/modelos.dart'`.

- [ ] **Paso 3: crear el modelo**

Crear `admin-panel/lib/modulos/flota/modelos.dart`:

```dart
import '../../core/formato.dart';

/// Disponibilidad que reporta el backend.
enum DisponibilidadConductor { disponible, ocupado, desconectado }

extension DisponibilidadConductorTexto on DisponibilidadConductor {
  String get etiqueta => switch (this) {
        DisponibilidadConductor.disponible => 'Disponible',
        DisponibilidadConductor.ocupado => 'Ocupado',
        DisponibilidadConductor.desconectado => 'Sin señal',
      };
}

/// Un conductor en el mapa de flota: sus datos (del snapshot REST) y su ultima posicion known
/// (del WebSocket). [aplicarPosicion] produce una copia con la posicion nueva, para no perder los
/// datos que solo llegan en el snapshot.
class ConductorEnVivo {
  /// Pasado este tiempo sin recibir posicion el conductor se dibuja como sin señal.
  static const Duration ventanaSenal = Duration(seconds: 30);

  final int idConductor;
  final String nombres;
  final String apellidos;
  final String? placa;
  final double? calificacion;
  final double? latitud;
  final double? longitud;
  final double? rumbo;
  final double? velocidad;
  final DisponibilidadConductor disponibilidad;
  final DateTime? actualizadoEn;

  const ConductorEnVivo({
    required this.idConductor,
    required this.nombres,
    required this.apellidos,
    required this.placa,
    required this.calificacion,
    required this.latitud,
    required this.longitud,
    required this.rumbo,
    required this.velocidad,
    required this.disponibilidad,
    required this.actualizadoEn,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  bool get tienePosicion => latitud != null && longitud != null;

  /// Sin posicion, o con una posicion mas vieja que [ventanaSenal], el conductor no tiene señal
  /// y el mapa lo dibuja en gris.
  bool esSinSenal(DateTime ahora) {
    if (!tienePosicion || actualizadoEn == null) return true;
    return ahora.difference(actualizadoEn!) > ventanaSenal;
  }

  ConductorEnVivo aplicarPosicion({
    required double latitud,
    required double longitud,
    double? rumbo,
    double? velocidad,
    required DisponibilidadConductor disponibilidad,
    required DateTime? actualizadoEn,
  }) {
    return ConductorEnVivo(
      idConductor: idConductor,
      nombres: nombres,
      apellidos: apellidos,
      placa: placa,
      calificacion: calificacion,
      latitud: latitud,
      longitud: longitud,
      rumbo: rumbo,
      velocidad: velocidad,
      disponibilidad: disponibilidad,
      actualizadoEn: actualizadoEn,
    );
  }

  /// Snapshot que devuelve GET /api/admin/conductores/ubicaciones.
  factory ConductorEnVivo.desdeJson(Map<String, dynamic> json) {
    return ConductorEnVivo(
      idConductor: Formato.leerEntero(json['idConductor']) ?? 0,
      nombres: (json['nombres'] as String?) ?? '',
      apellidos: (json['apellidos'] as String?) ?? '',
      placa: json['placa'] as String?,
      calificacion: Formato.leerDecimal(json['calificacionPromedio']),
      latitud: Formato.leerDecimal(json['latitud']),
      longitud: Formato.leerDecimal(json['longitud']),
      rumbo: Formato.leerDecimal(json['rumbo']),
      velocidad: Formato.leerDecimal(json['velocidad']),
      disponibilidad: leerDisponibilidad(json['disponibilidad']),
      actualizadoEn: Formato.leerFecha(json['actualizadoEn']),
    );
  }

  /// Delta que llega por /topic/admin/conductores. Conserva nombre, placa y calificacion del
  /// snapshot, porque el backend no los manda en cada posicion.
  factory ConductorEnVivo.desdeDelta(Map<String, dynamic> json, ConductorEnVivo anterior) {
    return ConductorEnVivo(
      idConductor: Formato.leerEntero(json['idConductor']) ?? anterior.idConductor,
      nombres: anterior.nombres,
      apellidos: anterior.apellidos,
      placa: anterior.placa,
      calificacion: anterior.calificacion,
      latitud: Formato.leerDecimal(json['latitud']),
      longitud: Formato.leerDecimal(json['longitud']),
      rumbo: Formato.leerDecimal(json['rumbo']),
      velocidad: Formato.leerDecimal(json['velocidad']),
      disponibilidad: leerDisponibilidad(json['disponibilidad']),
      actualizadoEn: Formato.leerFecha(json['actualizadoEn']),
    );
  }

  static DisponibilidadConductor leerDisponibilidad(dynamic valor) {
    return switch (valor) {
      'DISPONIBLE' => DisponibilidadConductor.disponible,
      'OCUPADO' => DisponibilidadConductor.ocupado,
      _ => DisponibilidadConductor.desconectado,
    };
  }
}
```

- [ ] **Paso 4: correr el test y verificar que pasa**

Correr: `cd admin-panel && flutter test test/conductor_en_vivo_test.dart`

Esperado: PASA, 7 tests.

- [ ] **Paso 5: crear la api**

Crear `admin-panel/lib/modulos/flota/flota_api.dart`:

```dart
import '../../core/cliente_api.dart';
import 'modelos.dart';

/// Endpoints de /api/admin del grupo de seguimiento en vivo.
class FlotaApi {
  final ClienteApi _api;

  FlotaApi(this._api);

  /// Snapshot de la flota: todos los conductores aprobados, con o sin posicion reportada.
  Future<List<ConductorEnVivo>> listarFlota() => _api.lista('/api/admin/conductores/ubicaciones', ConductorEnVivo.desdeJson);
}
```

- [ ] **Paso 6: correr el test y analizar**

Correr: `cd admin-panel && flutter test && flutter analyze`

Esperado: 11 tests en verde (4 de la tarea 5, 7 de esta) y `No issues found!`.

- [ ] **Paso 7: commit**

```bash
git add admin-panel/lib/modulos/flota admin-panel/test
git commit -m "panel admin: modelo y api de la flota de conductores"
```

---

### Tarea 7: Pantalla del mapa de flota

**Archivos:**
- Crear: `admin-panel/lib/modulos/flota/pantalla_conductores_vivo.dart`
- Modificar: `admin-panel/lib/core/menu.dart:30-36`
- Modificar: `admin-panel/lib/core/rutas.dart:9,41`

**Interfaces:**
- Consume: `ClienteStomp`, `EstadoWs` (tarea 5), `ConductorEnVivo`, `DisponibilidadConductor`,
  `FlotaApi` (tarea 6), `Zona` y `MapaApi` de `lib/modulos/mapa/`, `ColoresApp` de
  `lib/core/tema.dart`, `Formato`.
- Produce: ruta `/conductores-vivo` y la entrada de menu
  `Menu.conductoresVivo = ItemMenu('Conductores en vivo', FontAwesomeIcons.radar, '/conductores-vivo')`.

- [ ] **Paso 1: registrar la opcion de menu**

En `admin-panel/lib/core/menu.dart`, agregar el item junto a `mapa`:

```dart
  static const conductoresVivo = ItemMenu('Conductores en vivo', FontAwesomeIcons.radar, '/conductores-vivo');
```

y agregarlo al grupo Mapa:

```dart
  static const grupos = [
    GrupoMenu('Personas', FontAwesomeIcons.users, [personas, usuarios, pasajeros, conductores]),
    GrupoMenu('Mapa', FontAwesomeIcons.map, [zonas, mapa, conductoresVivo]),
  ];
```

- [ ] **Paso 2: registrar la ruta**

En `admin-panel/lib/core/rutas.dart`, agregar el import
`import '../modulos/flota/pantalla_conductores_vivo.dart';` y la ruta dentro del `ShellRoute`, junto
a la de `/mapa`:

```dart
          GoRoute(path: Menu.conductoresVivo.ruta, pageBuilder: (_, _) => pagina(const PantallaConductoresVivo())),
```

- [ ] **Paso 3: crear la pantalla**

Crear `admin-panel/lib/modulos/flota/pantalla_conductores_vivo.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/config.dart';
import '../../core/formato.dart';
import '../../core/sesion.dart';
import '../../core/stomp/cliente_stomp.dart';
import '../../core/tema.dart';
import '../mapa/mapa_api.dart';
import '../mapa/modelos.dart' show Zona;
import 'flota_api.dart';
import 'modelos.dart';

/// Mapa de flota: la posicion de los conductores en vivo por WebSocket.
///
/// El snapshot inicial (nombres, placas, calificacion) llega por REST y despues solo se pintan
/// deltas, que llegan con el topic /topic/admin/conductores. Los deltas entran en [_pendientes] y
/// se aplican en [_vaciarPendientes] como mucho cada 250 ms, para no redibujar el mapa en cada
/// mensaje: con 4 conductores reportando cada 2 segundos serian unos 8 setState por segundo.
class PantallaConductoresVivo extends StatefulWidget {
  const PantallaConductoresVivo({super.key});

  @override
  State<PantallaConductoresVivo> createState() => _PantallaConductoresVivoState();
}

class _PantallaConductoresVivoState extends State<PantallaConductoresVivo> {
  static const String TOPIC = '/topic/admin/conductores';
  static const Duration _repintado = Duration(milliseconds: 250);

  final MapController _controlador = MapController();
  final Map<int, ConductorEnVivo> _conductores = {};
  final Map<int, ConductorEnVivo> _pendientes = {};

  late final FlotaApi _api;
  ClienteStomp? _ws;
  StreamSubscription<Map<String, dynamic>>? _suscripcion;
  Timer? _temporizador;
  Timer? _recarga;

  List<Zona> _zonas = const [];
  bool _cargando = true;
  bool _mapaListo = false;
  bool _encuadrePendiente = false;
  bool _soloDisponibles = false;
  String? _error;
  int? _idSeguido;

  @override
  void initState() {
    super.initState();
    final cliente = context.read<ClienteApi>();
    _api = FlotaApi(cliente);
    _cargar();
    _conectar();
  }

  @override
  void dispose() {
    _recarga?.cancel();
    _temporizador?.cancel();
    _suscripcion?.cancel();
    _ws?.estado.removeListener(_alCambiarEstado);
    _ws?.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final flota = await _api.listarFlota();
      final zonas = await MapaApi(context.read<ClienteApi>()).listarZonas();
      if (!mounted) return;
      setState(() {
        for (final conductor in flota) {
          _conductores[conductor.idConductor] = conductor;
        }
        _zonas = zonas;
        _cargando = false;
      });
      _encuadrar();
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  void _encuadrar() {
    final puntos = <LatLng>[
      for (final zona in _zonas.where((z) => z.tienePoligono)) ...zona.puntos,
      for (final conductor in _conductores.values)
        if (conductor.tienePosicion) LatLng(conductor.latitud!, conductor.longitud!),
    ];
    if (puntos.isEmpty) return;
    if (!_mapaListo) {
      _encuadrePendiente = true;
      return;
    }
    _controlador.fitCamera(
      CameraFit.coordinates(coordinates: puntos, padding: const EdgeInsets.fromLTRB(48, 48, 48, 72), maxZoom: 16),
    );
  }

  void _conectar() {
    final token = context.read<Sesion>().tokenAcceso;
    if (token == null) return;
    final ws = ClienteStomp(url: '${Config.wsUrl}/ws', token: token, destino: TOPIC);
    _ws = ws;
    ws.estado.addListener(_alCambiarEstado);
    _suscripcion = ws.mensajes.listen(_alMensaje);
    ws.iniciar();
    _temporizador = Timer.periodic(_repintado, (_) => _vaciarPendientes());
  }

  void _alCambiarEstado() {
    if (mounted) setState(() {});
  }

  void _alMensaje(Map<String, dynamic> mensaje) {
    final id = Formato.leerEntero(mensaje['idConductor']);
    if (id == null) return;
    final actual = _conductores[id];
    if (actual == null) {
      // Conductor que aparecio despues de que el panel cargo: recarga el snapshot, una sola vez.
      _recarga ??= Timer(const Duration(seconds: 1), () {
        _recarga = null;
        _cargar();
      });
      return;
    }
    _pendientes[id] = ConductorEnVivo.desdeDelta(mensaje, actual);
  }

  void _vaciarPendientes() {
    if (_pendientes.isEmpty) return;
    final ahora = DateTime.now();
    for (final entrada in _pendientes.entries) {
      _conductores[entrada.key] = entrada.value;
    }
    _pendientes.clear();
    if (!mounted) return;
    setState(() {});

    final seguido = _idSeguido == null ? null : _conductores[_idSeguido];
    if (seguido == null || !seguido.tienePosicion) return;
    if (seguido.esSinSenal(ahora)) {
      // Perdio la señal: dejar de seguir para no perseguir un marcador congelado.
      setState(() => _idSeguido = null);
      return;
    }
    _controlador.move(LatLng(seguido.latitud!, seguido.longitud!), _controlador.camera.zoom);
  }

  List<ConductorEnVivo> get _visibles {
    final ahora = DateTime.now();
    final lista = _conductores.values.where((c) {
      if (_soloDisponibles && c.disponibilidad != DisponibilidadConductor.disponible) return false;
      return c.tienePosicion;
    }).toList();
    lista.sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    // El contenido del panel va dentro de un SingleChildScrollView de altura infinita, asi que el
    // mapa necesita una altura fija, igual que en pantalla_mapa.dart.
    final alto = (MediaQuery.sizeOf(context).height - 200).clamp(380.0, 860.0);
    return SizedBox(
      height: alto,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _barra(),
          Expanded(child: _mapa()),
        ],
      ),
    );
  }

  Widget _barra() {
    final ahora = DateTime.now();
    final visibles = _visibles;
    final disponibles = visibles.where((c) => c.disponibilidad == DisponibilidadConductor.disponible).length;
    final ocupados = visibles.where((c) => c.disponibilidad == DisponibilidadConductor.ocupado).length;
    final sinSenal = visibles.where((c) => c.esSinSenal(ahora)).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: ColoresApp.superficie,
        border: Border(bottom: BorderSide(color: ColoresApp.borde)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _pastillaConexion(),
          _contador(disponibles, ColoresApp.exito, 'disponibles'),
          _contador(ocupados, ColoresApp.azulClaro, 'ocupados'),
          _contador(sinSenal, ColoresApp.textoSuave, 'sin señal'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: _soloDisponibles,
                activeThumbColor: ColoresApp.rojo,
                onChanged: (valor) => setState(() => _soloDisponibles = valor),
              ),
              const Text('Solo disponibles', style: TextStyle(fontSize: 13, color: ColoresApp.texto)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pastillaConexion() {
    final estado = _ws?.estado.value ?? EstadoWs.desconectado;
    final (Color color, String texto) = switch (estado) {
      EstadoWs.conectado => (ColoresApp.exito, 'Conectado'),
      EstadoWs.conectando => (ColoresApp.azulClaro, 'Conectando'),
      EstadoWs.reconectando => (ColoresApp.rojo, 'Reconectando'),
      EstadoWs.desconectado => (ColoresApp.textoSuave, 'Sin conexión'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _contador(int cantidad, Color color, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$cantidad', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 5),
        Text(texto, style: const TextStyle(fontSize: 13, color: ColoresApp.texto)),
      ],
    );
  }

  Widget _mapa() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: ColoresApp.rojo));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(FontAwesomeIcons.triangleExclamation, color: ColoresApp.rojo, size: 28),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: ColoresApp.texto)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    final conPoligonos = _zonas.where((z) => z.tienePoligono).toList();
    return Stack(
      children: [
        FlutterMap(
          mapController: _controlador,
          options: MapOptions(
            initialCenter: const LatLng(-11.035287, -68.759348),
            initialZoom: 12,
            minZoom: 3,
            maxZoom: 18,
            backgroundColor: ColoresApp.azulNeblina,
            onMapReady: () {
              setState(() => _mapaListo = true);
              if (_encuadrePendiente) {
                _encuadrePendiente = false;
                _encuadrar();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'taxiuap.admin',
            ),
            PolygonLayer(
              polygons: [
                for (final zona in conPoligonos)
                  Polygon(
                    points: zona.puntos,
                    color: ColoresApp.azulClaro.withValues(alpha: 0.12),
                    borderColor: ColoresApp.azulClaro,
                    borderStrokeWidth: 2,
                  ),
              ],
            ),
            MarkerLayer(markers: [for (final c in _visibles) _marcador(c)]),
          ],
        ),
        if (_idSeguido != null) _pastillaSeguir(),
        if (_conductores.isEmpty)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: Text('No hay conductores aprobados')),
          ),
        const Positioned(right: 8, bottom: 6, child: _Credito()),
      ],
    );
  }

  Widget _pastillaSeguir() {
    final conductor = _conductores[_idSeguido!]!;
    return Positioned(
      left: 12,
      bottom: 24,
      child: Material(
        color: ColoresApp.superficie,
        borderRadius: BorderRadius.circular(RadiosApp.campo),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(RadiosApp.campo),
          onTap: () => setState(() => _idSeguido = null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FaIcon(FontAwesomeIcons.locationCrosshairs, color: ColoresApp.rojo, size: 14),
                const SizedBox(width: 8),
                Text('Siguiendo a ${conductor.nombreCompleto}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.azul)),
                const SizedBox(width: 10),
                const FaIcon(FontAwesomeIcons.xmark, color: ColoresApp.textoSuave, size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Marker _marcador(ConductorEnVivo conductor) {
    final sinSenal = conductor.esSinSenal(DateTime.now());
    final color = sinSenal
        ? ColoresApp.textoSuave
        : conductor.disponibilidad == DisponibilidadConductor.disponible
            ? ColoresApp.exito
            : ColoresApp.azulClaro;
    return Marker(
      point: LatLng(conductor.latitud!, conductor.longitud!),
      width: 46,
      height: 46,
      child: GestureDetector(
        onTap: () => _abrirDetalle(conductor),
        // El rumbo viene en grados desde el norte; el icono se dibuja apuntando al norte para que
        // el giro signifique la direccion real de marcha.
        child: Transform.rotate(
          angle: sinSenal ? 0 : (conductor.rumbo ?? 0) * 3.14159265358979 / 180,
          child: Center(
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: ColoresApp.superficie, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _abrirDetalle(ConductorEnVivo conductor) {
    showDialog<void>(
      context: context,
      builder: (_) => _ModalConductor(
        conductor: conductor,
        alCentrar: () => _centrar(conductor),
        alSeguir: () => setState(() => _idSeguido = conductor.idConductor),
        siguiendo: _idSeguido == conductor.idConductor,
        alDejarDeSeguir: () => setState(() => _idSeguido = null),
      ),
    );
  }

  void _centrar(ConductorEnVivo conductor) {
    if (!conductor.tienePosicion) return;
    _controlador.move(LatLng(conductor.latitud!, conductor.longitud!), 15);
  }
}

/// Modal con los datos del conductor: los mismos que el panel ya tiene, sin pedir nada al backend.
class _ModalConductor extends StatelessWidget {
  const _ModalConductor({
    required this.conductor,
    required this.alCentrar,
    required this.alSeguir,
    required this.siguiendo,
    required this.alDejarDeSeguir,
  });

  final ConductorEnVivo conductor;
  final VoidCallback alCentrar;
  final VoidCallback alSeguir;
  final bool siguiendo;
  final VoidCallback alDejarDeSeguir;

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ColoresApp.rojo, width: 3))),
          child: Row(
            children: [
              const FaIcon(FontAwesomeIcons.carSide, color: ColoresApp.azul, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  conductor.nombreCompleto,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ColoresApp.azul),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dato('Placa', conductor.placa ?? 'Sin vehiculo registrado'),
                _dato('Calificación', conductor.calificacion == null ? '' : '${conductor.calificacion!.toStringAsFixed(2)} de 5'),
                _dato('Disponibilidad', conductor.disponibilidad.etiqueta),
                _dato('Rumbo', conductor.rumbo == null ? '' : '${conductor.rumbo!.toStringAsFixed(0)} grados'),
                _dato('Velocidad', conductor.velocidad == null ? '' : '${conductor.velocidad!.toStringAsFixed(1)} km/h'),
                _dato('Última posición', conductor.actualizadoEn == null ? 'Sin señal' : '${Formato.fechaHora(conductor.actualizadoEn)} (${conductor.esSinSenal(ahora) ? 'sin señal' : 'en vivo'})'),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: ColoresApp.borde))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: conductor.tienePosicion ? alCentrar : null,
                icon: const FaIcon(FontAwesomeIcons.crosshairs, size: 14),
                label: const Text('Centrar'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: ColoresApp.rojo),
                onPressed: !conductor.tienePosicion
                    ? null
                    : siguiendo
                        ? alDejarDeSeguir
                        : () {
                            alSeguir();
                            Navigator.of(context).pop();
                          },
                icon: FaIcon(
                  siguiendo ? FontAwesomeIcons.xmark : FontAwesomeIcons.locationCrosshairs,
                  size: 14,
                ),
                label: Text(siguiendo ? 'Dejar de seguir' : 'Seguir'),
              ),
            ],
          ),
        ),
      ],
    );

    if (Pantalla.esMovil(context)) {
      return Dialog.fullscreen(backgroundColor: Colors.white, child: SafeArea(child: contenido));
    }
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: contenido),
    );
  }

  Widget _dato(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 12, color: ColoresApp.textoSuave)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontSize: 15, color: ColoresApp.texto)),
        ],
      ),
    );
  }
}

/// Credito obligatorio de OpenStreetMap.
class _Credito extends StatelessWidget {
  const _Credito();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: ColoresApp.superficie.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text('OpenStreetMap', style: TextStyle(fontSize: 10, color: ColoresApp.textoSuave)),
    );
  }
}
```

- [ ] **Paso 4: analizar**

Correr: `cd admin-panel && flutter analyze`

Esperado: `No issues found!`. Si marca `use_build_context_synchronously`, ya se esta usando
`if (!mounted) return;` antes de cada `setState`; el aviso puede venir del `MapaApi(context.read)`
dentro del `try` de `_cargar`, y se resuelve moviendo esa linea a antes del `try`:

```dart
    final mapaApi = MapaApi(context.read<ClienteApi>());
    try {
      final flota = await _api.listarFlota();
      final zonas = await mapaApi.listarZonas();
```

- [ ] **Paso 5: correr los tests**

Correr: `cd admin-panel && flutter test`

Esperado: 11 tests en verde.

- [ ] **Paso 6: commit**

```bash
git add admin-panel/lib/modulos/flota/pantalla_conductores_vivo.dart admin-panel/lib/core/menu.dart admin-panel/lib/core/rutas.dart
git commit -m "panel admin: mapa de flota de conductores en vivo"
```

---

### Tarea 8: Simulador de conductores

**Archivos:**
- Crear: `admin-panel/tool/simulador_conductores.dart`

**Interfaces:**
- Consume: `ClienteStomp` y `decodificarMensaje` de `lib/core/stomp/cliente_stomp.dart`,
  `Config.apiUrl` de `lib/core/config.dart`.
- Produce: un proceso que abre 4 conexiones STOMP (una por conductor del seed) y envia su posicion
  cada 2 o 3 segundos por `SEND /app/conductor/ubicacion`.

- [ ] **Paso 1: crear el simulador**

Crear `admin-panel/tool/simulador_conductores.dart`:

```dart
// Simulador de conductores: abre una conexion STOMP por cada conductor del seed y reporta su
// posicion, como haria la app del conductor. Es lo que permite ver el mapa de flota moverse antes
// de que exista driver-app.
//
// Uso: dart run tool/simulador_conductores.dart
// Contrasena de los usuarios de prueba: Taxi123* (la del seed del perfil xexel).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:taxiuap_admin/core/config.dart';
import 'package:taxiuap_admin/core/stomp/cliente_stomp.dart';

const _conductores = ['conductor1', 'conductor2', 'conductor3', 'conductor4'];
const _contrasena = 'Taxi123*';

/// Centro de Cobija (Pando) y radio,maximo en grados de cada passeio aleatorio.
const _centro = (-11.025, -68.760);
const _saltoMaximoGrados = 0.0025;
const _rumboInicial = [92.0, 180.0, 275.0, 350.0];

Future<String> iniciarSesion(String nombreUsuario) async {
  final respuesta = await http.post(
    Uri.parse('${Config.apiUrl}/api/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'usuario': nombreUsuario, 'password': _contrasena, 'rol': 'CONDUCTOR'}),
  );
  final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;
  if (respuesta.statusCode >= 400 || cuerpo['ok'] != true) {
    throw StateError('No se pudo iniciar sesion como $nombreUsuario: ${cuerpo['mensaje']}');
  }
  return (cuerpo['datos'] as Map<String, dynamic>)['tokenAcceso'] as String;
}

/// Paseo aleatorio: gira un poco en cada paso y vuelve al centro si se aleja demasiado, para que
/// los marcadores no se vayan de Cobija.
void main() async {
  print('Simulador de conductores contra ${Config.apiUrl}');
  final aleatorio = Random();
  final clientes = <ClienteStomp>[];
  final posiciones = <({double lat, double lon, double rumbo})>[];

  for (var i = 0; i < _conductores.length; i++) {
    final nombreUsuario = _conductores[i];
    final token = await iniciarSesion(nombreUsuario);
    print('  $nombreUsuario: sesion iniciada');
    final cliente = ClienteStomp(
      url: '${Config.wsUrl}/ws',
      token: token,
      destino: '/topic/admin/conductores',
    );
    cliente.iniciar();
    clientes.add(cliente);
    final rumbo = _rumboInicial[i];
    posiciones.add((lat: _centro.$1, lon: _centro.$2, rumbo: rumbo));
  }

  print('  4 conductores conectados;Ctrl+C para detener');
  var paso = 0;
  Timer.periodic(const Duration(milliseconds: 2500), (temporizador) {
    paso++;
    for (var i = 0; i < clientes.length; i++) {
      var posicion = posiciones[i];
      // Gira un poco y, de vez en cuando, cambia de rumbo por completo.
      final giro = (aleatorio.nextDouble() - 0.5) * 60;
      final rumbo = (posicion.rumbo + giro + 360) % 360;
      final distancia = _saltoMaximoGrados * (0.4 + aleatorio.nextDouble());
      final radianes = rumbo * 3.14159265358979 / 180;
      final nueva = (
        lat: posicion.lat + distancia * cos(radianes),
        lon: posicion.lon + distancia * sin(radianes),
        rumbo: rumbo,
      );
      // Vuelve al centro si se sale del area, para que no se vaya a otra ciudad.
      final lejos = (nueva.lat - _centro.$1).abs() > 0.03 || (nueva.lon - _centro.$2).abs() > 0.03;
      posicion = lejos ? (lat: _centro.$1, lon: _centro.$2, rumbo: rumbo) : nueva;
      posiciones[i] = posicion;

      clientes[i].enviar('/app/conductor/ubicacion', {
        'latitud': double.parse(posicion.lat.toStringAsFixed(6)),
        'longitud': double.parse(posicion.lon.toStringAsFixed(6)),
        'rumbo': double.parse(posicion.rumbo.toStringAsFixed(1)),
        'velocidad': double.parse((20 + aleatorio.nextDouble() * 25).toStringAsFixed(1)),
        // Cambia de disponibilidad cada 8 pasos para que se vean los tres colores.
        'disponibilidad': (paso ~/ 8 + i) % 2 == 0 ? 'DISPONIBLE' : 'OCUPADO',
      });
    }
  }, onDone: () {});

  // Al recibir Ctrl+C se desconectan los cuatro clientes.
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nDeteniendo el simulador');
    for (final cliente in clientes) {
      cliente.dispose();
    }
    exit(0);
  });

  // El cliente de suscripcion del simulador no se usa: solo envia. Sin esta linea el stream
  // queda abierto y el proceso no termina nunca.
  for (final cliente in clientes) {
    cliente.mensajes.listen((_) {});
  }
}
```

- [ ] **Paso 2: analizar el simulador**

Correr: `cd admin-panel && flutter analyze tool/simulador_conductores.dart`

Esperado: `No issues found!`. El error mas probable es `cos` y `sin`: vienen de `dart:math`, que ya
esta importado. Si Dart se queja de que una tupla con nombre necesita el paquete `records`, no: los
records con nombre son de Dart 3.0 en adelante y el SDK es ^3.13.4.

- [ ] **Paso 3: probar el login del simulador**

Con el backend arriba:

```bash
cd admin-panel && dart run tool/simulador_conductores.dart
```

Esperado: imprime `Simulador de conductores contra http://localhost:8080`, luego
`conductor1: sesion iniciada` hasta `conductor4: sesion iniciada`, y despues
`4 conductores conectados; Ctrl+C para detener`. Si dice que no puede iniciar sesion, el backend no
esta arriba o la base no tiene el seed.

- [ ] **Paso 4: comprobar que el backend recibe las posiciones**

Con el simulador corriendo, en otra terminal:

```bash
docker exec taxiuap-db psql -U postgres -d taxiuap -c "select count(*), max(actualizado_en) from ubicacion_conductor"
```

Esperado: 4 filas y `actualizado_en` con la hora actual, que cambia cada 2 o 3 segundos. Si el count
sigue en 4 pero `actualizado_en` no avanza, el backend esta guardando pero el simulador no manda
(imprime errores de STOMP).

- [ ] **Paso 5: detener el simulador**

Correr `Ctrl+C` en la terminal del simulador.

Esperado: imprime `Deteniendo el simulador` y el proceso termina.

- [ ] **Paso 6: commit**

```bash
git add admin-panel/tool
git commit -m "panel admin: simulador de conductores por stomp"
```

---

### Tarea 9: Verificacion de punta a punta y estado del proyecto

**Archivos:**
- Modificar: `CLAUDE.md` (seccion "Estado del proyecto")

**Interfaces:**
- Consume: todo lo anterior.
- Produce: la funcionalidad verificada y el estado del proyecto al dia.

- [ ] **Paso 1: levantar el entorno**

```bash
cd /home/arcangel/IdeaProjects/UniTaxi-V0.2 && docker compose up -d
cd backend && ./gradlew bootRun
```

Esperado: el backend arranca sin errores y el log de DataSeeder dice
`6 conductores (4 aprobados, 1 pendiente, 1 rechazado)`.

- [ ] **Paso 2: verificar los endpoints con curl**

Con el token de admin (`admin` / la clave de `ADMIN_PASSWORD` del perfil xexel):

```bash
curl -s -X POST http://localhost:8080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"usuario":"admin","password":"<clave>","rol":"ADMIN"}'
```

Copiar `tokenAcceso` y luego:

```bash
curl -s http://localhost:8080/api/admin/conductores/ubicaciones \
  -H "Authorization: Bearer <token>"
```

Esperado: `{"ok":true,"datos":[ ... ]}` con 4 conductores, cada uno con `nombres`, `apellidos`,
`placa`, coordenadas en el area de Cobija y `disponibilidad`.

- [ ] **Paso 3: verificar que el endpoint exige ADMIN**

Repetir el `GET` con el token de un pasajero (`pasajero1` / `Taxi123*`, rol PASAJERO).

Esperado: HTTP 403 con el JSON de `accessDeniedHandler`.

- [ ] **Paso 4: probar el mapa en el panel**

```bash
cd admin-panel && flutter run -d chrome --web-port 5173
```

Con el simulador corriendo en otra terminal, entrar al panel, ir a **Mapa > Conductores en vivo** y
comprobar, en este orden:

1. La pastilla dice `Conectado` y hay 4 marcadores.
2. Los marcadores se mueven solos.
3. Los colores cambian a verde, azul y gris con el tiempo.
4. Al hacer clic se abre el modal con nombre, placa, calificación, rumbo, velocidad y hora.
5. "Seguir" cierra el modal y la cámara sigue al conductor; aparece la pastilla "Siguiendo a"; al
   tocarla se deja de seguir.
6. "Solo disponibles" quita del mapa los que no están en DISPONIBLE.
7. Al apagar el simulador, los marcadores quedan grises y la pastilla termina en "Sin conexión".

- [ ] **Paso 5: comprobar que un pasajero no entra al topic de administradores**

Escribir `admin-panel/tool/prueba_topic_admin.dart`:

```dart
// Comprobacion manual: un pasajero no puede suscribirse a /topic/admin/conductores.
// Uso: dart run tool/prueba_topic_admin.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:taxiuap_admin/core/config.dart';
import 'package:taxiuap_admin/core/stomp/cliente_stomp.dart';

void main() async {
  final respuesta = await http.post(
    Uri.parse('${Config.apiUrl}/api/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'usuario': 'pasajero1', 'password': 'Taxi123*', 'rol': 'PASAJERO'}),
  );
  final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;
  final token = (cuerpo['datos'] as Map<String, dynamic>)['tokenAcceso'] as String;

  final cliente = ClienteStomp(
    url: '${Config.wsUrl}/ws',
    token: token,
    destino: '/topic/admin/conductores',
  );
  var rechazado = false;
  cliente.estado.addListener(() {
    if (cliente.estado.value == EstadoWs.reconectando || cliente.estado.value == EstadoWs.desconectado) {
      rechazado = true;
    }
  });
  cliente.iniciar();
  await Future<void>.delayed(const Duration(seconds: 6));
  await cliente.dispose();

  print(rechazado
      ? 'OK: el pasajero no pudo suscribirse al topic de administradores'
      : 'FALLO: el pasajero entro al topic de administradores');
}
```

Correr: `cd admin-panel && dart run tool/prueba_topic_admin.dart`

Esperado: `OK: el pasajero no pudo suscribirse al topic de administradores`. Si imprime `FALLO`, el
gate de rol de la tarea 4 no esta aplicandose.

- [ ] **Paso 5b: borrar el archivo de prueba**

Borrar `admin-panel/tool/prueba_topic_admin.dart` y no hacer commit de el: era una comprobacion de un
solo uso, no una herramienta del proyecto.

- [ ] **Paso 6: correr toda la suite**

```bash
cd backend && ./gradlew build
cd ../admin-panel && flutter test && flutter analyze
cd .. && git status
```

Esperado: build sin errores, 21 tests backend en verde, 11 tests del panel en verde, analyze sin
avisos, y `git status` con solo `CLAUDE.md` modificado.

- [ ] **Paso 7: actualizar el estado del proyecto**

En `CLAUDE.md`, en la seccion "Estado del proyecto", agregar una linea marcada:

```
- [x] Seguimiento de conductores en tiempo real: ingesta STOMP (/app/conductor/ubicacion), topic
      /topic/admin/conductores con gate de administrador, snapshot REST, mapa de flota con detalle
      y modo Seguir, y simulador para probar sin la app del conductor
```

- [ ] **Paso 8: commit**

```bash
git add CLAUDE.md
git commit -m "estado del proyecto: seguimiento de conductores en tiempo real"
```

---

## Notas de riesgo

- **`stomp_dart_client` en web**: si en lugar de `stompConnectHeaders` hubiera que usar
  `webSocketConnectHeaders`, el backend recibiria la peticion sin token y rechazaria el `CONNECT`.
  El sintoma es una pastilla que nunca pasa de "Conectando". En ese caso tocar
  `WebSocketConfig.java:102` para leer tambien el query string es el plan B.
- **Predicado N+1 en `listarFlota`**: las tres consultas batch evitan leer persona y vehiculo uno por
  uno. Si el log de SQL muestra mas de tres consultas por llamada, revisar que los `join fetch` de
  `findAprobadosParaFlota` y `findDeConductores` sigan en su sitio.
- **Formato de fecha**: `actualizadoEn` llega como texto ISO y el panel lo lee con
  `Formato.leerFecha`. Si el backend lo serializara como arreglo numerico, el panel lo veria como
  `null` y todos los marcadores saldrian sin señal.
