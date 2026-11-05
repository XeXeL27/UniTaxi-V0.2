package com.taxiuap.backend.pricing.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.taxiuap.backend.pricing.dto.DescuentoEstudianteRequest;
import com.taxiuap.backend.pricing.dto.ParametrosPrecio;
import com.taxiuap.backend.pricing.dto.PrecioBaseRequest;
import com.taxiuap.backend.pricing.dto.TramoPrecioRequest;
import com.taxiuap.backend.pricing.entity.TramoPrecio;
import com.taxiuap.backend.pricing.enums.ServicioPrecio;
import com.taxiuap.backend.pricing.repository.TramoPrecioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.sistema.entity.ConfiguracionSistema;
import com.taxiuap.backend.sistema.repository.ConfiguracionSistemaRepository;

/** Tablas de precios por servicio (moto taxi, paquete y delivery) con la BD en memoria. */
class ParametrosPrecioServiceTest {

    private final Map<String, ConfiguracionSistema> filas = new HashMap<>();
    private final List<TramoPrecio> tramos = new ArrayList<>();
    private ParametrosPrecioService service;

    @BeforeEach
    void preparar() {
        ConfiguracionSistemaRepository configuracion = mock(ConfiguracionSistemaRepository.class);
        when(configuracion.findByClave(any())).thenAnswer(i -> Optional.ofNullable(filas.get(i.<String>getArgument(0))));
        when(configuracion.save(any())).thenAnswer(i -> {
            ConfiguracionSistema fila = i.getArgument(0);
            filas.put(fila.getClave(), fila);
            return fila;
        });
        TramoPrecioRepository repositorio = mock(TramoPrecioRepository.class);
        when(repositorio.findByServicioAndEstadoTramoOrderByOrdenAscIdAsc(any(), any())).thenAnswer(i -> tramos.stream()
                .filter(t -> t.getServicio() == i.getArgument(0) && t.getEstadoTramo() == i.getArgument(1))
                .sorted(Comparator.comparing(TramoPrecio::getOrden).thenComparing(TramoPrecio::getId))
                .toList());
        when(repositorio.countByServicio(any()))
                .thenAnswer(i -> tramos.stream().filter(t -> t.getServicio() == i.getArgument(0)).count());
        when(repositorio.findById(any()))
                .thenAnswer(i -> tramos.stream().filter(t -> t.getId().equals(i.getArgument(0))).findFirst());
        when(repositorio.save(any())).thenAnswer(i -> {
            TramoPrecio tramo = i.getArgument(0);
            if (tramo.getId() == null) {
                tramo.setId(tramos.size() + 1);
                tramos.add(tramo);
            }
            return tramo;
        });
        when(repositorio.asignarTaxiALosDeAntes()).thenAnswer(i -> {
            int cambiados = 0;
            for (TramoPrecio t : tramos) {
                if (t.getServicio() == null) {
                    t.setServicio(ServicioPrecio.TAXI);
                    cambiados++;
                }
            }
            return cambiados;
        });
        // Tarifa de antes del delivery: 8 Bs + 2 Bs por km (la del paquete, sin guardar, la misma).
        TarifaDeliveryService anterior = new TarifaDeliveryService(configuracion, new BigDecimal("8"), new BigDecimal("2"));
        service = new ParametrosPrecioService(configuracion, repositorio, anterior);
    }

    @Test
    void elPaqueteYElDeliveryEmpiezanConUnaTablaParecidaALaDeAntesEnBsEnteros() {
        service.crearTablasDeEnvioIniciales();

        for (ServicioPrecio servicio : List.of(ServicioPrecio.PAQUETE, ServicioPrecio.DELIVERY)) {
            ParametrosPrecio tabla = service.actuales(servicio);
            assertEquals(new BigDecimal("8.00"), tabla.precioBase());
            assertEquals(0, BigDecimal.ONE.compareTo(tabla.kmBase()));
            assertEquals(1, tabla.tramos().size());
            assertEquals(0, BigDecimal.ONE.compareTo(tabla.tramos().get(0).kmAdicional()));
            assertEquals(new BigDecimal("2.00"), tabla.tramos().get(0).costoAdicional());
            // Al lado del cliente 8 Bs (antes 8,02), a 3 km 12 Bs.
            assertEquals(new BigDecimal("8.00"), tabla.precioPara(new BigDecimal("0.01")));
            assertEquals(new BigDecimal("12.00"), tabla.precioPara(new BigDecimal("3")));
        }
        // El moto taxi no se toca.
        assertEquals(0, service.actuales(ServicioPrecio.TAXI).tramos().size());
    }

    @Test
    void laTablaInicialSeCreaUnaSolaVezYRedondeaHaciaArriba() {
        guardar("paquete.tarifa-base", "6.50");
        guardar("paquete.precio-km", "1.20");

        service.crearTablasDeEnvioIniciales();
        service.crearTablasDeEnvioIniciales();

        ParametrosPrecio paquete = service.actuales(ServicioPrecio.PAQUETE);
        assertEquals(new BigDecimal("7.00"), paquete.precioBase());
        assertEquals(1, paquete.tramos().size());
        assertEquals(new BigDecimal("2.00"), paquete.tramos().get(0).costoAdicional());
        assertEquals(2, tramos.size());
    }

    @Test
    void siElAdministradorBorroTodosLosTramosNoSeVuelvenACrear() {
        service.crearTablasDeEnvioIniciales();
        Integer id = service.actuales(ServicioPrecio.DELIVERY).tramos().get(0).id();
        service.eliminarTramo(ServicioPrecio.DELIVERY, id);

        service.crearTablasDeEnvioIniciales();

        assertEquals(0, service.actuales(ServicioPrecio.DELIVERY).tramos().size());
    }

    @Test
    void cadaServicioTieneSuTablaAparte() {
        service.crearTramosIniciales();
        service.guardarBase(ServicioPrecio.PAQUETE, new PrecioBaseRequest(new BigDecimal("6"), new BigDecimal("2")));
        service.crearTramo(ServicioPrecio.PAQUETE, new TramoPrecioRequest(new BigDecimal("2"), new BigDecimal("3")));
        service.guardarBase(ServicioPrecio.DELIVERY, new PrecioBaseRequest(new BigDecimal("9"), BigDecimal.ONE));

        ParametrosPrecio paquete = service.actuales(ServicioPrecio.PAQUETE);
        assertEquals(new BigDecimal("6"), paquete.precioBase());
        assertEquals(1, paquete.tramos().size());
        assertEquals(new BigDecimal("9.00"), paquete.precioPara(new BigDecimal("3.5")));
        assertEquals(new BigDecimal("9"), service.actuales(ServicioPrecio.DELIVERY).precioBase());
        // El taxi sigue con su base de siempre y sus dos tramos (+3 km +2 Bs).
        ParametrosPrecio taxi = service.actuales();
        assertEquals(new BigDecimal("8.00"), taxi.precioBase());
        assertEquals(2, taxi.tramos().size());
        assertEquals("6", filas.get("paquete.precio-base").getValor());
        assertEquals("9", filas.get("delivery.precio-base").getValor());
    }

    @Test
    void unTramoDeOtroServicioNoSeEditaNiSeElimina() {
        service.crearTramosIniciales();
        Integer delTaxi = service.actuales().tramos().get(0).id();

        assertThrows(RecursoNoEncontradoException.class, () -> service.editarTramo(ServicioPrecio.PAQUETE, delTaxi,
                new TramoPrecioRequest(BigDecimal.ONE, BigDecimal.ONE)));
        assertThrows(RecursoNoEncontradoException.class, () -> service.eliminarTramo(ServicioPrecio.DELIVERY, delTaxi));
        assertEquals(EstadoRegistro.A, tramos.get(0).getEstadoTramo());
    }

    @Test
    void elDescuentoDeEstudianteSoloLimitaAlMotoTaxi() {
        service.guardarDescuento(new DescuentoEstudianteRequest(3, null));

        assertThrows(NegocioException.class, () -> service.guardarBase(ServicioPrecio.TAXI,
                new PrecioBaseRequest(new BigDecimal("3"), BigDecimal.ONE)));
        // El paquete puede costar menos que el descuento: no tiene descuento.
        ParametrosPrecio paquete = service.guardarBase(ServicioPrecio.PAQUETE,
                new PrecioBaseRequest(new BigDecimal("2"), BigDecimal.ONE));
        assertEquals(0, paquete.descuentoEstudiante());
        assertEquals(3, service.actuales().descuentoEstudiante());
    }

    @Test
    void losTramosDeAntesDeSepararLosServiciosQuedanDelMotoTaxi() {
        TramoPrecio viejo = new TramoPrecio();
        viejo.setId(1);
        viejo.setServicio(null);
        viejo.setOrden(1);
        viejo.setKmAdicional(new BigDecimal("3"));
        viejo.setCostoAdicional(new BigDecimal("2.00"));
        tramos.add(viejo);

        service.crearTramosIniciales();

        assertEquals(ServicioPrecio.TAXI, viejo.getServicio());
        assertEquals(1, service.actuales().tramos().size());
    }

    private void guardar(String clave, String valor) {
        ConfiguracionSistema fila = new ConfiguracionSistema();
        fila.setClave(clave);
        fila.setValor(valor);
        filas.put(clave, fila);
    }
}
