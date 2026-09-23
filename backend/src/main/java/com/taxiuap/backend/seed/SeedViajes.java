package com.taxiuap.backend.seed;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Component;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.institution.entity.Estudiante;
import com.taxiuap.backend.pricing.entity.BilleteraConductor;
import com.taxiuap.backend.pricing.entity.Comision;
import com.taxiuap.backend.pricing.entity.Pago;
import com.taxiuap.backend.pricing.entity.ReglaDescuentoEstudiantil;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.pricing.enums.MetodoPago;
import com.taxiuap.backend.pricing.enums.SituacionPago;
import com.taxiuap.backend.pricing.repository.BilleteraConductorRepository;
import com.taxiuap.backend.pricing.repository.ComisionRepository;
import com.taxiuap.backend.pricing.repository.PagoRepository;
import com.taxiuap.backend.seed.SeedCatalogos.CatalogosSembrados;
import com.taxiuap.backend.seed.SeedPrecios.PreciosSembrados;
import com.taxiuap.backend.seed.SeedUsuarios.UsuariosSembrados;
import com.taxiuap.backend.trip.entity.HistorialEstadoViaje;
import com.taxiuap.backend.trip.entity.OfertaViaje;
import com.taxiuap.backend.trip.entity.PuntoRecorrido;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.CanceladoPor;
import com.taxiuap.backend.trip.enums.SituacionOferta;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.repository.HistorialEstadoViajeRepository;
import com.taxiuap.backend.trip.repository.OfertaViajeRepository;
import com.taxiuap.backend.trip.repository.PuntoRecorridoRepository;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.trip.repository.ViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.Vehiculo;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Siembra los viajes de prueba: 10 completados (al menos 3 con descuento estudiantil), 2
 * cancelados, una solicitud pendiente sin ofertas, una solicitud con 3 ofertas pendientes y un
 * viaje en curso. Cada viaje completado incluye su solicitud, oferta aceptada, historial de
 * estados, puntos de recorrido, pago y comision, y actualiza la billetera del conductor.
 */
@Component
@RequiredArgsConstructor
@Slf4j
class SeedViajes {

    /** Porcentaje de comision de la plataforma usado en el seed (igual al valor por defecto de produccion). */
    private static final BigDecimal PORCENTAJE_COMISION = new BigDecimal("15.00");

    private final SolicitudViajeRepository solicitudViajeRepository;
    private final OfertaViajeRepository ofertaViajeRepository;
    private final ViajeRepository viajeRepository;
    private final HistorialEstadoViajeRepository historialEstadoViajeRepository;
    private final PuntoRecorridoRepository puntoRecorridoRepository;
    private final PagoRepository pagoRepository;
    private final ComisionRepository comisionRepository;
    private final BilleteraConductorRepository billeteraConductorRepository;

    /** Resultado de la siembra de viajes, usado por el bloque de comunicacion. */
    record ViajesSembrados(
            List<Viaje> completados,
            Viaje viajeEnCurso,
            List<Viaje> cancelados,
            SolicitudViaje solicitudPendiente,
            SolicitudViaje solicitudConOfertas) {
    }

    /** Configuracion de un viaje historico completado, usada para no repetir el mismo alta a mano diez veces. */
    private record ConfigViajeCompletado(
            Pasajero pasajero,
            Conductor conductor,
            Vehiculo vehiculo,
            CategoriaServicio categoriaServicio,
            Tarifa tarifa,
            BigDecimal distanciaKm,
            int duracionMin,
            long diasAtras,
            boolean conDescuento,
            Estudiante estudiante,
            ReglaDescuentoEstudiantil regla) {
    }

    ViajesSembrados sembrar(CatalogosSembrados catalogos, UsuariosSembrados usuarios, PreciosSembrados precios) {
        log.info("Sembrando viajes historicos...");

        List<ConfigViajeCompletado> configuraciones = construirConfiguraciones(usuarios, precios);

        List<Viaje> completados = new ArrayList<>();
        int conDescuento = 0;
        for (ConfigViajeCompletado config : configuraciones) {
            Viaje viaje = crearViajeCompletado(config);
            completados.add(viaje);
            if (config.conDescuento()) {
                conDescuento++;
            }
        }

        log.info("Sembrando viajes cancelados...");
        List<Viaje> cancelados = List.of(
                crearViajeCancelado(usuarios.pasajero(5), usuarios.conductorAprobado(0), usuarios.vehiculoAprobado(0),
                        usuarios.categoriaAprobado(0), precios.tarifaSedanEstandarCentro(), CanceladoPor.PASAJERO, 18),
                crearViajeCancelado(usuarios.pasajero(6), usuarios.conductorAprobado(1), usuarios.vehiculoAprobado(1),
                        usuarios.categoriaAprobado(1), precios.tarifaSedanEjecutivoCentro(), CanceladoPor.CONDUCTOR, 12));

        log.info("Sembrando solicitud pendiente sin ofertas y solicitud con 3 ofertas...");
        SolicitudViaje solicitudPendiente = crearSolicitudPendiente(usuarios.pasajero(7), usuarios.categoriaAprobado(0));
        SolicitudViaje solicitudConOfertas = crearSolicitudConOfertas(usuarios);

        log.info("Sembrando viaje en curso...");
        Viaje viajeEnCurso = crearViajeEnCurso(usuarios.pasajero(2), usuarios.conductorAprobado(2),
                usuarios.vehiculoAprobado(2), usuarios.categoriaAprobado(2), precios.tarifaMotoCentro());

        log.info("Viajes sembrados: {} completados ({} con descuento estudiantil), {} cancelados, "
                        + "1 solicitud pendiente, 1 solicitud con ofertas, 1 viaje en curso",
                completados.size(), conDescuento, cancelados.size());

        return new ViajesSembrados(completados, viajeEnCurso, cancelados, solicitudPendiente, solicitudConOfertas);
    }

    private List<ConfigViajeCompletado> construirConfiguraciones(UsuariosSembrados usuarios, PreciosSembrados precios) {
        Estudiante estudianteAna = usuarios.estudiantesConMatricula().get(0);
        Estudiante estudianteBeatriz = usuarios.estudiantesConMatricula().get(1);
        ReglaDescuentoEstudiantil regla = precios.reglaDescuentoSedanUniversidad();

        return List.of(
                new ConfigViajeCompletado(usuarios.pasajero(0), usuarios.conductorAprobado(0), usuarios.vehiculoAprobado(0),
                        usuarios.categoriaAprobado(0), precios.tarifaSedanEstandarCentro(),
                        new BigDecimal("3.20"), 12, 29, true, estudianteAna, regla),
                new ConfigViajeCompletado(usuarios.pasajero(4), usuarios.conductorAprobado(2), usuarios.vehiculoAprobado(2),
                        usuarios.categoriaAprobado(2), precios.tarifaMotoCentro(),
                        new BigDecimal("2.10"), 9, 26, false, null, null),
                new ConfigViajeCompletado(usuarios.pasajero(1), usuarios.conductorAprobado(1), usuarios.vehiculoAprobado(1),
                        usuarios.categoriaAprobado(1), precios.tarifaSedanEjecutivoCentro(),
                        new BigDecimal("5.50"), 18, 23, true, estudianteBeatriz, regla),
                new ConfigViajeCompletado(usuarios.pasajero(5), usuarios.conductorAprobado(3), usuarios.vehiculoAprobado(3),
                        usuarios.categoriaAprobado(3), precios.tarifaSedanEstandarCentro(),
                        new BigDecimal("4.00"), 15, 20, false, null, null),
                new ConfigViajeCompletado(usuarios.pasajero(2), usuarios.conductorAprobado(0), usuarios.vehiculoAprobado(0),
                        usuarios.categoriaAprobado(0), precios.tarifaSedanEstandarCentro(),
                        new BigDecimal("6.80"), 22, 17, false, null, null),
                new ConfigViajeCompletado(usuarios.pasajero(0), usuarios.conductorAprobado(3), usuarios.vehiculoAprobado(3),
                        usuarios.categoriaAprobado(3), precios.tarifaSedanEstandarCentro(),
                        new BigDecimal("2.90"), 11, 14, true, estudianteAna, regla),
                new ConfigViajeCompletado(usuarios.pasajero(6), usuarios.conductorAprobado(2), usuarios.vehiculoAprobado(2),
                        usuarios.categoriaAprobado(2), precios.tarifaMotoCentro(),
                        new BigDecimal("1.80"), 7, 11, false, null, null),
                new ConfigViajeCompletado(usuarios.pasajero(3), usuarios.conductorAprobado(1), usuarios.vehiculoAprobado(1),
                        usuarios.categoriaAprobado(1), precios.tarifaSedanEjecutivoCentro(),
                        new BigDecimal("7.30"), 24, 8, false, null, null),
                new ConfigViajeCompletado(usuarios.pasajero(7), usuarios.conductorAprobado(0), usuarios.vehiculoAprobado(0),
                        usuarios.categoriaAprobado(0), precios.tarifaSedanEstandarCentro(),
                        new BigDecimal("3.60"), 13, 5, false, null, null),
                new ConfigViajeCompletado(usuarios.pasajero(1), usuarios.conductorAprobado(2), usuarios.vehiculoAprobado(2),
                        usuarios.categoriaAprobado(2), precios.tarifaMotoCentro(),
                        new BigDecimal("2.50"), 10, 2, false, null, null));
    }

    private Viaje crearViajeCompletado(ConfigViajeCompletado config) {
        LocalDateTime fechaSolicitud = LocalDateTime.now().minusDays(config.diasAtras()).withHour(9).withMinute(0);
        LocalDateTime fechaConfirmado = fechaSolicitud.plusMinutes(3);
        LocalDateTime fechaEnCamino = fechaConfirmado.plusMinutes(1);
        LocalDateTime fechaLlego = fechaEnCamino.plusMinutes(5);
        LocalDateTime fechaInicio = fechaLlego.plusMinutes(1);
        LocalDateTime fechaFin = fechaInicio.plusMinutes(config.duracionMin());

        Point origen = puntoAlAzarEnCobija(0);
        Point destino = puntoAlAzarEnCobija(1);

        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setPasajero(config.pasajero());
        solicitud.setCategoriaServicio(config.categoriaServicio());
        solicitud.setOrigen(origen);
        solicitud.setDestino(destino);
        solicitud.setOrigenDireccion("Origen de prueba, Cobija");
        solicitud.setDestinoDireccion("Destino de prueba, Cobija");
        BigDecimal precioOriginal = calcularPrecio(config.tarifa(), config.distanciaKm(), config.duracionMin());
        solicitud.setPrecioSugerido(precioOriginal);
        solicitud.setSituacionSolicitud(SituacionSolicitud.ACEPTADA);
        solicitud.setFechaSolicitud(fechaSolicitud);
        solicitud = solicitudViajeRepository.save(solicitud);

        OfertaViaje oferta = new OfertaViaje();
        oferta.setSolicitud(solicitud);
        oferta.setConductor(config.conductor());
        oferta.setPrecioOfertado(precioOriginal);
        oferta.setTiempoLlegadaMin(5);
        oferta.setSituacionOferta(SituacionOferta.ACEPTADA);
        oferta.setFechaOferta(fechaSolicitud.plusMinutes(2));
        ofertaViajeRepository.save(oferta);

        BigDecimal montoDescuento = BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP);
        if (config.conDescuento()) {
            montoDescuento = precioOriginal
                    .multiply(config.regla().getPorcentaje())
                    .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP)
                    .min(config.regla().getMontoMaximo());
        }
        BigDecimal precioFinal = precioOriginal.subtract(montoDescuento).setScale(2, RoundingMode.HALF_UP);

        Viaje viaje = new Viaje();
        viaje.setSolicitud(solicitud);
        viaje.setPasajero(config.pasajero());
        viaje.setConductor(config.conductor());
        viaje.setVehiculo(config.vehiculo());
        viaje.setCategoriaServicio(config.categoriaServicio());
        viaje.setTarifa(config.tarifa());
        if (config.conDescuento()) {
            viaje.setEstudiante(config.estudiante());
            viaje.setReglaDescuento(config.regla());
        }
        viaje.setOrigen(origen);
        viaje.setDestino(destino);
        viaje.setDistanciaKm(config.distanciaKm());
        viaje.setDuracionMin(config.duracionMin());
        viaje.setPrecioOriginal(precioOriginal);
        viaje.setMontoDescuento(montoDescuento);
        viaje.setPrecioFinal(precioFinal);
        viaje.setSituacionViaje(SituacionViaje.COMPLETADO);
        viaje.setFechaInicio(fechaInicio);
        viaje.setFechaFin(fechaFin);
        viaje = viajeRepository.save(viaje);

        Usuario usuarioConductor = config.conductor().getUsuario();
        registrarHistorial(viaje, SituacionViaje.CONFIRMADO, usuarioConductor, fechaConfirmado);
        registrarHistorial(viaje, SituacionViaje.CONDUCTOR_EN_CAMINO, usuarioConductor, fechaEnCamino);
        registrarHistorial(viaje, SituacionViaje.CONDUCTOR_LLEGO, usuarioConductor, fechaLlego);
        registrarHistorial(viaje, SituacionViaje.EN_CURSO, usuarioConductor, fechaInicio);
        registrarHistorial(viaje, SituacionViaje.COMPLETADO, usuarioConductor, fechaFin);

        crearPuntosRecorrido(viaje, origen, destino, fechaInicio, fechaFin, 5 + (int) (config.diasAtras() % 6));

        MetodoPago metodoPago = config.diasAtras() % 2 == 0 ? MetodoPago.EFECTIVO : MetodoPago.QR;
        procesarPagoYComision(viaje, metodoPago, fechaFin);

        return viaje;
    }

    private Viaje crearViajeCancelado(Pasajero pasajero, Conductor conductor, Vehiculo vehiculo,
            CategoriaServicio categoriaServicio, Tarifa tarifa, CanceladoPor canceladoPor, long diasAtras) {
        LocalDateTime fechaSolicitud = LocalDateTime.now().minusDays(diasAtras).withHour(15).withMinute(0);
        LocalDateTime fechaConfirmado = fechaSolicitud.plusMinutes(3);
        LocalDateTime fechaCancelado = fechaConfirmado.plusMinutes(4);

        Point origen = puntoAlAzarEnCobija(2);
        Point destino = puntoAlAzarEnCobija(3);

        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(categoriaServicio);
        solicitud.setOrigen(origen);
        solicitud.setDestino(destino);
        solicitud.setOrigenDireccion("Origen de prueba, Cobija");
        solicitud.setDestinoDireccion("Destino de prueba, Cobija");
        BigDecimal precioOriginal = calcularPrecio(tarifa, new BigDecimal("3.00"), 10);
        solicitud.setPrecioSugerido(precioOriginal);
        solicitud.setSituacionSolicitud(SituacionSolicitud.CANCELADA);
        solicitud.setFechaSolicitud(fechaSolicitud);
        solicitud = solicitudViajeRepository.save(solicitud);

        OfertaViaje oferta = new OfertaViaje();
        oferta.setSolicitud(solicitud);
        oferta.setConductor(conductor);
        oferta.setPrecioOfertado(precioOriginal);
        oferta.setTiempoLlegadaMin(6);
        oferta.setSituacionOferta(SituacionOferta.ACEPTADA);
        oferta.setFechaOferta(fechaSolicitud.plusMinutes(2));
        ofertaViajeRepository.save(oferta);

        Viaje viaje = new Viaje();
        viaje.setSolicitud(solicitud);
        viaje.setPasajero(pasajero);
        viaje.setConductor(conductor);
        viaje.setVehiculo(vehiculo);
        viaje.setCategoriaServicio(categoriaServicio);
        viaje.setTarifa(tarifa);
        viaje.setOrigen(origen);
        viaje.setDestino(destino);
        viaje.setDistanciaKm(new BigDecimal("3.00"));
        viaje.setDuracionMin(10);
        viaje.setPrecioOriginal(precioOriginal);
        viaje.setMontoDescuento(BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP));
        viaje.setPrecioFinal(precioOriginal);
        viaje.setSituacionViaje(SituacionViaje.CANCELADO);
        viaje.setCanceladoPor(canceladoPor);
        viaje = viajeRepository.save(viaje);

        Usuario usuarioQueCancela = canceladoPor == CanceladoPor.PASAJERO
                ? pasajero.getUsuario()
                : conductor.getUsuario();
        registrarHistorial(viaje, SituacionViaje.CONFIRMADO, conductor.getUsuario(), fechaConfirmado);
        registrarHistorial(viaje, SituacionViaje.CANCELADO, usuarioQueCancela, fechaCancelado);

        return viaje;
    }

    private SolicitudViaje crearSolicitudPendiente(Pasajero pasajero, CategoriaServicio categoriaServicio) {
        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(categoriaServicio);
        solicitud.setOrigen(puntoAlAzarEnCobija(4));
        solicitud.setDestino(puntoAlAzarEnCobija(5));
        solicitud.setOrigenDireccion("Origen de prueba, Cobija");
        solicitud.setDestinoDireccion("Destino de prueba, Cobija");
        solicitud.setPrecioSugerido(new BigDecimal("15.00"));
        solicitud.setSituacionSolicitud(SituacionSolicitud.PENDIENTE);
        solicitud.setFechaSolicitud(LocalDateTime.now().minusMinutes(10));
        return solicitudViajeRepository.save(solicitud);
    }

    private SolicitudViaje crearSolicitudConOfertas(UsuariosSembrados usuarios) {
        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setPasajero(usuarios.pasajero(4));
        solicitud.setCategoriaServicio(usuarios.categoriaAprobado(0));
        solicitud.setOrigen(puntoAlAzarEnCobija(6));
        solicitud.setDestino(puntoAlAzarEnCobija(7));
        solicitud.setOrigenDireccion("Origen de prueba, Cobija");
        solicitud.setDestinoDireccion("Destino de prueba, Cobija");
        solicitud.setPrecioSugerido(new BigDecimal("18.00"));
        solicitud.setSituacionSolicitud(SituacionSolicitud.CON_OFERTAS);
        solicitud.setFechaSolicitud(LocalDateTime.now().minusMinutes(6));
        solicitud = solicitudViajeRepository.save(solicitud);

        BigDecimal[] precios = { new BigDecimal("17.00"), new BigDecimal("18.00"), new BigDecimal("16.50") };
        int[] tiempos = { 4, 6, 5 };
        for (int i = 0; i < usuarios.conductoresAprobados().size() - 1; i++) {
            OfertaViaje oferta = new OfertaViaje();
            oferta.setSolicitud(solicitud);
            oferta.setConductor(usuarios.conductorAprobado(i));
            oferta.setPrecioOfertado(precios[i]);
            oferta.setTiempoLlegadaMin(tiempos[i]);
            oferta.setSituacionOferta(SituacionOferta.PENDIENTE);
            oferta.setFechaOferta(LocalDateTime.now().minusMinutes(5 - i));
            ofertaViajeRepository.save(oferta);
        }

        return solicitud;
    }

    private Viaje crearViajeEnCurso(Pasajero pasajero, Conductor conductor, Vehiculo vehiculo,
            CategoriaServicio categoriaServicio, Tarifa tarifa) {
        LocalDateTime fechaSolicitud = LocalDateTime.now().minusMinutes(25);
        LocalDateTime fechaConfirmado = fechaSolicitud.plusMinutes(2);
        LocalDateTime fechaEnCamino = fechaConfirmado.plusMinutes(1);
        LocalDateTime fechaLlego = fechaEnCamino.plusMinutes(6);
        LocalDateTime fechaInicio = fechaLlego.plusMinutes(1);

        Point origen = puntoAlAzarEnCobija(8);
        Point destino = puntoAlAzarEnCobija(9);

        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setPasajero(pasajero);
        solicitud.setCategoriaServicio(categoriaServicio);
        solicitud.setOrigen(origen);
        solicitud.setDestino(destino);
        solicitud.setOrigenDireccion("Origen de prueba, Cobija");
        solicitud.setDestinoDireccion("Destino de prueba, Cobija");
        BigDecimal precioOriginal = calcularPrecio(tarifa, new BigDecimal("4.50"), 15);
        solicitud.setPrecioSugerido(precioOriginal);
        solicitud.setSituacionSolicitud(SituacionSolicitud.ACEPTADA);
        solicitud.setFechaSolicitud(fechaSolicitud);
        solicitud = solicitudViajeRepository.save(solicitud);

        OfertaViaje oferta = new OfertaViaje();
        oferta.setSolicitud(solicitud);
        oferta.setConductor(conductor);
        oferta.setPrecioOfertado(precioOriginal);
        oferta.setTiempoLlegadaMin(6);
        oferta.setSituacionOferta(SituacionOferta.ACEPTADA);
        oferta.setFechaOferta(fechaSolicitud.plusMinutes(1));
        ofertaViajeRepository.save(oferta);

        Viaje viaje = new Viaje();
        viaje.setSolicitud(solicitud);
        viaje.setPasajero(pasajero);
        viaje.setConductor(conductor);
        viaje.setVehiculo(vehiculo);
        viaje.setCategoriaServicio(categoriaServicio);
        viaje.setTarifa(tarifa);
        viaje.setOrigen(origen);
        viaje.setDestino(destino);
        viaje.setDistanciaKm(new BigDecimal("4.50"));
        viaje.setDuracionMin(15);
        viaje.setPrecioOriginal(precioOriginal);
        viaje.setMontoDescuento(BigDecimal.ZERO.setScale(2, RoundingMode.HALF_UP));
        viaje.setPrecioFinal(precioOriginal);
        viaje.setSituacionViaje(SituacionViaje.EN_CURSO);
        viaje.setFechaInicio(fechaInicio);
        viaje = viajeRepository.save(viaje);

        Usuario usuarioConductor = conductor.getUsuario();
        registrarHistorial(viaje, SituacionViaje.CONFIRMADO, usuarioConductor, fechaConfirmado);
        registrarHistorial(viaje, SituacionViaje.CONDUCTOR_EN_CAMINO, usuarioConductor, fechaEnCamino);
        registrarHistorial(viaje, SituacionViaje.CONDUCTOR_LLEGO, usuarioConductor, fechaLlego);
        registrarHistorial(viaje, SituacionViaje.EN_CURSO, usuarioConductor, fechaInicio);

        crearPuntosRecorrido(viaje, origen, destino, fechaInicio, LocalDateTime.now(), 4);

        return viaje;
    }

    private void registrarHistorial(Viaje viaje, SituacionViaje situacion, Usuario usuarioCambio, LocalDateTime fecha) {
        HistorialEstadoViaje historial = new HistorialEstadoViaje();
        historial.setViaje(viaje);
        historial.setUsuarioCambio(usuarioCambio);
        historial.setSituacionViaje(situacion);
        historial.setFecha(fecha);
        historialEstadoViajeRepository.save(historial);
    }

    private void crearPuntosRecorrido(Viaje viaje, Point origen, Point destino, LocalDateTime desde,
            LocalDateTime hasta, int cantidad) {
        double lonOrigen = origen.getX();
        double latOrigen = origen.getY();
        double lonDestino = destino.getX();
        double latDestino = destino.getY();
        long totalSegundos = Math.max(1, java.time.Duration.between(desde, hasta).getSeconds());

        for (int i = 0; i < cantidad; i++) {
            double proporcion = cantidad == 1 ? 0 : (double) i / (cantidad - 1);
            double lon = lonOrigen + (lonDestino - lonOrigen) * proporcion;
            double lat = latOrigen + (latDestino - latOrigen) * proporcion;

            PuntoRecorrido punto = new PuntoRecorrido();
            punto.setViaje(viaje);
            punto.setUbicacion(GeometriaSeed.punto(lon, lat));
            punto.setRegistradoEn(desde.plusSeconds((long) (totalSegundos * proporcion)));
            puntoRecorridoRepository.save(punto);
        }
    }

    /**
     * Regla de negocio 7: al completar el viaje se crea el pago (COMPLETADO, para tener datos ya
     * cerrados) y la comision de la plataforma, y se actualiza la billetera del conductor segun
     * el metodo de pago, igual que en ViajeService.
     */
    private void procesarPagoYComision(Viaje viaje, MetodoPago metodoPago, LocalDateTime fechaPago) {
        Pago pago = new Pago();
        pago.setViaje(viaje);
        pago.setMetodoPago(metodoPago);
        pago.setMonto(viaje.getPrecioFinal());
        pago.setSituacionPago(SituacionPago.COMPLETADO);
        pago.setFechaPago(fechaPago);
        pagoRepository.save(pago);

        BigDecimal montoComision = viaje.getPrecioFinal()
                .multiply(PORCENTAJE_COMISION)
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);

        Comision comision = new Comision();
        comision.setViaje(viaje);
        comision.setPorcentaje(PORCENTAJE_COMISION);
        comision.setMonto(montoComision);
        comisionRepository.save(comision);

        BilleteraConductor billetera = billeteraConductorRepository.findByConductorId(viaje.getConductor().getId())
                .orElseThrow(() -> new IllegalStateException(
                        "Billetera no sembrada para el conductor " + viaje.getConductor().getId()));

        if (metodoPago == MetodoPago.EFECTIVO) {
            billetera.setDeudaComision(billetera.getDeudaComision().add(montoComision).setScale(2, RoundingMode.HALF_UP));
        } else {
            BigDecimal neto = viaje.getPrecioFinal().subtract(montoComision);
            billetera.setSaldo(billetera.getSaldo().add(neto).setScale(2, RoundingMode.HALF_UP));
        }
        billetera.setActualizadoEn(fechaPago);
        billeteraConductorRepository.save(billetera);
    }

    private BigDecimal calcularPrecio(Tarifa tarifa, BigDecimal distanciaKm, int duracionMin) {
        BigDecimal precio = tarifa.getTarifaBase()
                .add(tarifa.getPrecioKm().multiply(distanciaKm))
                .add(tarifa.getPrecioMinuto().multiply(BigDecimal.valueOf(duracionMin)));
        if (precio.compareTo(tarifa.getTarifaMinima()) < 0) {
            precio = tarifa.getTarifaMinima();
        }
        return precio.setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * Puntos de origen/destino de prueba, dispersos dentro de Cobija alrededor de su centro
     * (longitud -68.76, latitud -11.02). El indice solo se usa para separar visualmente los
     * distintos viajes de prueba entre si.
     */
    private Point puntoAlAzarEnCobija(int indice) {
        double desplazamiento = 0.004 * (indice % 10 - 5);
        double longitud = GeometriaSeed.LONGITUD_CENTRO_COBIJA + desplazamiento;
        double latitud = GeometriaSeed.LATITUD_CENTRO_COBIJA - desplazamiento;
        return GeometriaSeed.punto(longitud, latitud);
    }
}
