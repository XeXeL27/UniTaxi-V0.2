package com.taxiuap.backend.seed;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.repository.RolRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Punto de entrada de los datos de prueba de TaxiUAP. Solo corre en el perfil xexel y solo si
 * taxiuap.seed.habilitado=true; nunca debe ejecutarse en produccion ni duplicar datos si ya
 * existen (por eso siempre se verifica antes de insertar nada).
 *
 * La carga en si (SeedOrquestador.sembrarTodo) se divide en un componente por dominio, en orden
 * de dependencias: catalogos -> usuarios (personas, pasajeros, conductores, vehiculos,
 * documentos) -> precios (tarifas, descuentos) -> viajes historicos -> comunicacion
 * (calificaciones, mensajes, SOS, reportes).
 *
 * Corre despues de AdminInitializer (@Order), porque necesita los roles que este siembra.
 */
@Component
@Profile("appu")
@Order(2)
@RequiredArgsConstructor
@Slf4j
public class DataSeeder implements CommandLineRunner {

    /** Nombre de usuario de uno de los pasajeros de prueba, usado como marca para saber si el seed ya corrio. */
    private static final String USUARIO_MARCA_SEED = "pasajero1";

    @Value("${taxiuap.seed.habilitado:false}")
    private boolean seedHabilitado;

    private final RolRepository rolRepository;
    private final UsuarioRepository usuarioRepository;
    private final SeedOrquestador seedOrquestador;

    @Override
    public void run(String... args) {
        if (!seedHabilitado) {
            log.info("Seed de datos de prueba deshabilitado (taxiuap.seed.habilitado=false): no se hace nada");
            return;
        }

        if (yaExistenDatosDePrueba()) {
            log.info("Los datos de prueba ya existen (se encontro el usuario {}): no se vuelve a sembrar",
                    USUARIO_MARCA_SEED);
            return;
        }

        seedOrquestador.sembrarTodo();
    }

    /**
     * Idempotencia: si ya hay roles Y ya existe el nombre de usuario de uno de los pasajeros de prueba,
     * asumimos que el seed ya corrio una vez y no se toca nada. Correr esto dos veces seguidas
     * es seguro: la segunda vez simplemente no hace nada.
     */
    private boolean yaExistenDatosDePrueba() {
        return rolRepository.count() > 0
                && usuarioRepository.existsByNombreUsuarioAndRolCodigo(USUARIO_MARCA_SEED, RolSistema.PASAJERO.getCodigo());
    }
}
