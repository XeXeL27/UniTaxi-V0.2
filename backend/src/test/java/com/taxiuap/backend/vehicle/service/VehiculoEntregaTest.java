package com.taxiuap.backend.vehicle.service;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.when;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.vehicle.dto.VehiculoRequest;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

class VehiculoEntregaTest {

    @Mock private VehiculoRepository vehiculoRepository;
    @Mock private ConductorRepository conductorRepository;
    @Mock private TipoVehiculoRepository tipoVehiculoRepository;
    @Mock private CategoriaServicioRepository categoriaServicioRepository;

    private VehiculoService service;

    @BeforeEach
    void setUp() {
        org.mockito.MockitoAnnotations.openMocks(this);
        service = new VehiculoService(vehiculoRepository, conductorRepository,
                tipoVehiculoRepository, categoriaServicioRepository);
    }

    @Test
    void rechazaDeliveryParaVehiculoNoMoto() {
        Conductor conductor = new Conductor();
        conductor.setId(1L);
        TipoVehiculo sedan = tipo(1, "SEDAN");
        CategoriaServicio deliverySedan = categoria(2, "DELIVERY", sedan);

        when(conductorRepository.findByUsuarioId(10L)).thenReturn(Optional.of(conductor));
        when(vehiculoRepository.findByPlaca("ABC123")).thenReturn(Optional.empty());
        when(tipoVehiculoRepository.findById(1)).thenReturn(Optional.of(sedan));
        when(categoriaServicioRepository.findById(2)).thenReturn(Optional.of(deliverySedan));

        assertThrows(NegocioException.class, () -> service.crear(10L,
                new VehiculoRequest("ABC123", "Honda", "CB", "Rojo", 2020, 1, 2)));
    }

    @Test
    void vehiculoDeliveryExigeTipoMotoYCategoriaDelivery() {
        TipoVehiculo sedan = tipo(1, "SEDAN");
        TipoVehiculo moto = tipo(2, "MOTO");
        CategoriaServicio delivery = categoria(3, "DELIVERY", moto);
        Vehiculo vehiculo = new Vehiculo();
        vehiculo.setTipoVehiculo(sedan);
        vehiculo.setCategoriaServicio(delivery);

        org.junit.jupiter.api.Assertions.assertFalse(vehiculo.esMotoDelivery());

        vehiculo.setTipoVehiculo(moto);
        org.junit.jupiter.api.Assertions.assertTrue(vehiculo.esMotoDelivery());
    }

    private static TipoVehiculo tipo(int id, String codigo) {
        TipoVehiculo tipo = new TipoVehiculo();
        tipo.setId(id);
        tipo.setCodigo(codigo);
        return tipo;
    }

    private static CategoriaServicio categoria(int id, String nombre, TipoVehiculo tipo) {
        CategoriaServicio categoria = new CategoriaServicio();
        categoria.setId(id);
        categoria.setNombre(nombre);
        categoria.setTipoVehiculo(tipo);
        return categoria;
    }
}
