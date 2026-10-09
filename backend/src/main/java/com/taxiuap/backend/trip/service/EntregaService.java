package com.taxiuap.backend.trip.service;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.communication.entity.Reporte;
import com.taxiuap.backend.communication.enums.SituacionReporte;
import com.taxiuap.backend.communication.repository.ReporteRepository;
import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.archivo.ProcesadorImagen;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.dto.ConfirmarPagoEntregaRequest;
import com.taxiuap.backend.trip.dto.FinalizarViajeRequest;
import com.taxiuap.backend.trip.dto.IdentificarReceptorRequest;
import com.taxiuap.backend.trip.dto.ProponerCompraRequest;
import com.taxiuap.backend.trip.dto.RegistrarCompraRequest;
import com.taxiuap.backend.trip.dto.ValidarCodigoEntregaRequest;
import com.taxiuap.backend.trip.dto.LlegadaEntregaRequest;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.enums.TipoFotoEntrega;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;

/**
 * Acciones propias de DELIVERY. ViajeService mantiene el ciclo del viaje (aceptar, cancelar,
 * finalizar) y aqui vive lo que un taxi no tiene: validar los codigos que dicta cada parte, coordinar
 * la compra con el cliente y registrar el pago directo del producto.
 *
 * <p>Todas las transiciones se aplican con UPDATE condicional sobre {@code estado_entrega} (y el codigo
 * cuando aplica), de modo que una doble pulsacion o dos pantallas simultaneas no puedan hacer avanzar el
 * pedido dos veces: la segunda no actualiza ninguna fila.</p>
 */
@Service
public class EntregaService {

    /** Estados en los que el repartidor todavia no tiene el pedido y puede actuar sobre el. */
    private static final List<EstadoEntrega> ANTES_DE_TENER_EL_PEDIDO =
            List.of(EstadoEntrega.PENDIENTE_RECOGIDA, EstadoEntrega.EN_CAMINO_RECOGIDA);

    /** Con el pedido en mano solo cabe una accion: entregar o reportar que no se pudo. */
    private static final List<EstadoEntrega> CON_PEDIDO_EN_MANO = List.of(EstadoEntrega.EN_MANO);

    /** La entrega se confirma con el GPS del repartidor a esta distancia o menos del destino (B). */
    public static final double METROS_MAXIMOS_ENTREGA = 100;

    private static final String NOMBRE_CONSTANCIA = "constancia_entrega.txt";
    private static final DateTimeFormatter FECHA_CONSTANCIA = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final ViajeService viajeService;
    private final DatosEntregaRepository datosEntregaRepository;
    private final CalculoPrecioDeliveryService calculoPrecioDeliveryService;
    private final AlmacenamientoArchivos almacenamientoArchivos;
    private final ReporteRepository reporteRepository;

    @org.springframework.beans.factory.annotation.Autowired
    public EntregaService(ViajeService viajeService,
            DatosEntregaRepository datosEntregaRepository,
            CalculoPrecioDeliveryService calculoPrecioDeliveryService,
            AlmacenamientoArchivos almacenamientoArchivos, ReporteRepository reporteRepository) {
        this.viajeService = viajeService;
        this.datosEntregaRepository = datosEntregaRepository;
        this.calculoPrecioDeliveryService = calculoPrecioDeliveryService;
        this.almacenamientoArchivos = almacenamientoArchivos;
        this.reporteRepository = reporteRepository;
    }

    /** Constructor de compatibilidad para pruebas unitarias antiguas del flujo DELIVERY. */
    public EntregaService(ViajeService viajeService, DatosEntregaRepository datosEntregaRepository,
            CalculoPrecioDeliveryService calculoPrecioDeliveryService,
            AlmacenamientoArchivos almacenamientoArchivos) {
        this(viajeService, datosEntregaRepository, calculoPrecioDeliveryService, almacenamientoArchivos, null);
    }

    // ---------------------------------------------------------------- COMPRA_Y_ENTREGA: la compra

    /**
     * COMPRA_Y_ENTREGA: el repartidor propone donde comprar antes de gastar el dinero de otra persona.
     * La propuesta es una expectativa, no una compra: queda con el monto que el cliente deberia
     * confirmar. Proponer de nuevo invalida la confirmacion anterior, porque el cliente confirmo un
     * comercio y un monto concretos.
     */
    @Transactional
    public ViajeResponse proponerCompra(Long idViaje, ProponerCompraRequest request) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.COMPRA_Y_ENTREGA);
        exigirEstado(datos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO);
        if (request.detalleCompra() == null || request.detalleCompra().isBlank()) {
            throw new NegocioException("Describe el comercio donde comprarias el producto");
        }
        // Una compra por encima del limite no debio llegar a mostrarse; si llego (el limite pudo
        // bajar despues), el repartidor no puede proponer gastarlo.
        if (!calculoPrecioDeliveryService.puedeAdelantar(request.costoProducto(),
                viaje.getConductor().getLimiteAdelantoCompra())) {
            throw new NegocioException("El monto supera tu limite de adelanto para compras");
        }

        datos.setPuntoCompraPropuesto(PuntoDesdeWkt.convertir(request.puntoCompraWkt()));
        datos.setDetalleCompraPropuesto(request.detalleCompra().trim());
        datos.setCostoProductoConfirmado(dinero(request.costoProducto()));
        datos.setCompraConfirmadaPorCliente(false);
        datosEntregaRepository.save(datos);
        return viajeService.obtener(idViaje);
    }

    /**
     * COMPRA_Y_ENTREGA: el cliente confirma el comercio y el monto que el repartidor propuso. Sin esta
     * confirmacion el repartidor no puede comprar, y el monto real nunca puede superar al confirmado:
     * si se pasa, tiene que volver a proponer y volver a recibir la confirmacion.
     */
    @Transactional
    public ViajeResponse confirmarCompra(Long idViaje) {
        Viaje viaje = viajeService.obtenerViajeDelPasajero(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.COMPRA_Y_ENTREGA);
        exigirEstado(datos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO);
        if (datos.getCostoProductoConfirmado() == null
                || (datos.getDetalleCompraPropuesto() == null && datos.getPuntoCompraPropuesto() == null)) {
            throw new NegocioException("El repartidor todavia no propuso donde comprar el producto");
        }

        datos.setCompraConfirmadaPorCliente(true);
        datosEntregaRepository.save(datos);
        return viajeService.obtener(idViaje);
    }

    /**
     * COMPRA_Y_ENTREGA: compra ya hecha. El pedido pasa a EN_MANO con el punto de compra real y el
     * costo real, y el precio del servicio se recalcula desde el comercio hasta el destino: el trayecto
     * del repartidor hasta el comercio no se cobra. El producto queda fuera del precio de la plataforma
     * porque la comision no aplica actualmente a DELIVERY.
     */
    @Transactional
    public ViajeResponse registrarCompra(Long idViaje, RegistrarCompraRequest request, MultipartFile comprobante) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.COMPRA_Y_ENTREGA);
        exigirEstado(datos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO);
        if (!Boolean.TRUE.equals(datos.getCompraConfirmadaPorCliente())) {
            throw new NegocioException("El cliente todavia no confirmo la compra: no compres antes");
        }
        BigDecimal confirmado = datos.getCostoProductoConfirmado();
        if (confirmado == null || request.costoProducto().compareTo(confirmado) > 0) {
            throw new NegocioException("El costo real supera el monto confirmado: pide una nueva "
                    + "confirmacion del cliente antes de comprar");
        }

        // El comprobante se procesa antes de tocar el estado: si la imagen no sirve, el pedido no avanza.
        byte[] contenidoComprobante = imagenOpcional(comprobante, "El comprobante");
        Point puntoCompra = PuntoDesdeWkt.convertir(request.puntoCompraWkt());
        Long idSolicitud = viaje.getSolicitud().getId();
        Point destino = viaje.getDestino();
        BigDecimal costoReal = dinero(request.costoProducto());
        Long idDatos = datos.getId();
        // El recibo se escribe antes del UPDATE: despues, el viaje ya no esta en el contexto de persistencia.
        String rutaComprobante = contenidoComprobante == null ? null
                : guardarEvidencia(contenidoComprobante, viaje, "comprobante_compra");

        int filas = datosEntregaRepository.avanzarSiEstadoPermitido(idDatos, ANTES_DE_TENER_EL_PEDIDO,
                EstadoEntrega.EN_MANO);
        if (filas == 0) {
            throw transicionRechazada(idDatos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO,
                    "El pedido ya no se puede comprar");
        }

        // El UPDATE condicional limpio el contexto de persistencia: se relee el pedido antes de escribir.
        DatosEntrega actualizada = datosEntregaRepository.findBySolicitudId(idSolicitud)
                .orElseThrow(() -> new NegocioException("El pedido ya no existe"));
        actualizada.setPuntoCompra(puntoCompra);
        actualizada.setDetalleCompra(request.detalleCompra().trim());
        actualizada.setCostoProductoReal(costoReal);
        actualizada.setObservacionCompra(textoOpcional(request.observacionCompra()));
        actualizada.setFechaRecogida(LocalDateTime.now());
        if (rutaComprobante != null) {
            actualizada.setFotoComprobanteUrl(rutaComprobante);
        }
        datosEntregaRepository.save(actualizada);

        DesglosePrecioDelivery precio = calculoPrecioDeliveryService.fijarPrecioCompra(puntoCompra, destino);
        ViajeResponse respuesta = viajeService.registrarPedidoEnMano(idViaje, precio);
        actualizarConstancia(idViaje);
        return respuesta;
    }

    // ---------------------------------------------------------------- ENCOMIENDA: recogida en A

    /**
     * El repartidor llego al punto de recogida (A). Recien ahi puede validar el codigo del remitente:
     * hasta este paso la app le muestra solo el punto A, y al cliente le llega el aviso.
     */
    @Transactional
    public ViajeResponse llegadaRecogida(Long idViaje) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        if (!ANTES_DE_TENER_EL_PEDIDO.contains(datos.getEstadoEntrega())) {
            throw new NegocioException("El paquete ya fue recogido");
        }
        datos.setFechaLlegadaRecogida(LocalDateTime.now());
        datosEntregaRepository.save(datos);
        ViajeResponse respuesta = viajeService.llegadaRecogida(idViaje);
        actualizarConstancia(idViaje);
        return respuesta;
    }

    /**
     * ENCOMIENDA: el repartidor llego a A, el remitente le dicta el codigo de recogida y toma la foto
     * del paquete (obligatoria). Con el codigo correcto el pedido pasa a EN_MANO, el viaje a EN_CURSO
     * y empieza la entrega hacia B. El codigo incorrecto no avanza nada (la foto ya escrita se borra al
     * deshacerse la transaccion) y se responde con un mensaje generico.
     */
    @Transactional
    public ViajeResponse validarRecogida(Long idViaje, ValidarCodigoEntregaRequest request, MultipartFile foto) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.ENCOMIENDA);
        exigirEstado(datos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO);
        if (viaje.getSituacionViaje() != SituacionViaje.CONDUCTOR_LLEGO) {
            throw new NegocioException("Marca primero que llegaste al punto de recogida");
        }
        byte[] contenido = imagenObligatoria(foto, "La foto del paquete");
        String rutaFoto = guardarEvidencia(contenido, viaje, "recogida");
        Point ubicacion = PuntoDesdeWkt.desdeCoordenadas(request.latitud(), request.longitud());
        Long idSolicitud = viaje.getSolicitud().getId();
        Long idDatos = datos.getId();

        int filas = datosEntregaRepository.avanzarSiCodigoRecogidaCoincide(idDatos, ANTES_DE_TENER_EL_PEDIDO,
                EstadoEntrega.EN_MANO, request.codigo());
        if (filas == 0) {
            throw transicionRechazada(idDatos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO,
                    "El codigo de recogida no coincide");
        }

        DatosEntrega actualizada = datosEntregaRepository.findBySolicitudId(idSolicitud)
                .orElseThrow(() -> new NegocioException("El pedido ya no existe"));
        actualizada.setFotoRecogidaUrl(rutaFoto);
        actualizada.setFechaRecogida(LocalDateTime.now());
        actualizada.setUbicacionRecogida(ubicacion);
        datosEntregaRepository.save(actualizada);

        // El precio no cambia: el codigo de recogida solo confirma la entrega fisica del paquete.
        ViajeResponse respuesta = viajeService.registrarPedidoEnMano(idViaje, null);
        avisarCliente(idViaje, "PAQUETE_RECOGIDO", "Tu paquete fue recogido",
                " ya tiene tu paquete y va en camino al destino.");
        actualizarConstancia(idViaje);
        return respuesta;
    }

    // ---------------------------------------------------------------- pago directo al cliente

    /**
     * DELIVERY: el cliente paga al repartidor, producto mas servicio, sin pasarela. El repartidor
     * declara cuanto recibio y el servidor comprueba que sea exactamente el total a cobrar, para que
     * el monto que queda registrado como ganancia del repartidor no dependa de lo que el declare.
     */
    @Transactional
    public ViajeResponse confirmarPago(Long idViaje, ConfirmarPagoEntregaRequest request) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirEstado(datos, CON_PEDIDO_EN_MANO, EstadoEntrega.EN_MANO);

        BigDecimal total = totalACobrar(datos, viaje);
        if (request.montoRecibido() == null || request.montoRecibido().compareTo(total) != 0) {
            throw new NegocioException("El pago registrado (" + dinero(request.montoRecibido())
                    + ") no coincide con el total a cobrar " + total);
        }

        int filas = datosEntregaRepository.confirmarPagoSiEnMano(datos.getId(), EstadoEntrega.EN_MANO, total);
        if (filas == 0) {
            EstadoEntrega actual = datosEntregaRepository.findById(datos.getId())
                    .map(DatosEntrega::getEstadoEntrega)
                    .orElse(null);
            if (actual == null || actual != EstadoEntrega.EN_MANO) {
                throw new NegocioException("Transicion de estado no permitida: " + actual + " -> ENTREGADO");
            }
            throw new NegocioException("El pago ya fue confirmado");
        }
        if (request.metodoPago() != null) {
            viajeService.cambiarMetodoPago(idViaje, request.metodoPago());
        }
        return viajeService.obtener(idViaje);
    }

    // ---------------------------------------------------------------- entrega en B

    /**
     * ENCOMIENDA: en B el receptor dicta el codigo de entrega. Con el codigo correcto, el pago ya
     * confirmado, el pedido queda ENTREGADO y el viaje
     * COMPLETADO.
     */
    @Transactional
    public ViajeResponse entregarConCodigo(Long idViaje, ValidarCodigoEntregaRequest request, MultipartFile foto) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.ENCOMIENDA);
        exigirEstado(datos, CON_PEDIDO_EN_MANO, EstadoEntrega.ENTREGADO);
        exigirPagoConfirmado(datos);
        Point ubicacion = exigirCercaDelDestino(viaje, request.latitud(), request.longitud());
        byte[] contenido = imagenObligatoria(foto, "La foto de la entrega");
        String rutaFoto = guardarEvidencia(contenido, viaje, "entrega");
        Long idSolicitud = viaje.getSolicitud().getId();
        Long idDatos = datos.getId();

        int filas = datosEntregaRepository.avanzarSiCodigoEntregaCoincide(idDatos, CON_PEDIDO_EN_MANO,
                EstadoEntrega.ENTREGADO, request.codigo());
        if (filas == 0) {
            throw transicionRechazada(idDatos, CON_PEDIDO_EN_MANO, EstadoEntrega.ENTREGADO,
                    "El codigo de entrega no coincide");
        }

        registrarEvidenciaEntrega(idSolicitud, rutaFoto, ubicacion, null);
        return completarEntrega(idViaje);
    }

    /**
     * COMPRA_Y_ENTREGA: no hay codigo, el receptor siempre es el cliente que creo el pedido. Se
     * comprueba que quien firma sea ese cliente (nombre y, si el cliente tiene telefono registrado,
     * tambien el telefono) para que otra persona no pueda recibir el pedido.
     */
    @Transactional
    public ViajeResponse entregarConReceptor(Long idViaje,
            IdentificarReceptorRequest request, MultipartFile foto) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.COMPRA_Y_ENTREGA);
        exigirEstado(datos, CON_PEDIDO_EN_MANO, EstadoEntrega.ENTREGADO);
        exigirPagoConfirmado(datos);
        validarReceptor(viaje, request);
        Point ubicacion = exigirCercaDelDestino(viaje, request.latitud(), request.longitud());
        byte[] contenido = imagenObligatoria(foto, "La foto de la entrega");
        String rutaFoto = guardarEvidencia(contenido, viaje, "entrega");
        Long idSolicitud = viaje.getSolicitud().getId();

        int filas = datosEntregaRepository.avanzarSiEstadoPermitido(datos.getId(), CON_PEDIDO_EN_MANO,
                EstadoEntrega.ENTREGADO);
        if (filas == 0) {
            throw transicionRechazada(datos.getId(), CON_PEDIDO_EN_MANO, EstadoEntrega.ENTREGADO,
                    "El pedido ya no se puede entregar");
        }

        registrarEvidenciaEntrega(idSolicitud, rutaFoto, ubicacion, request.nombre().trim());
        return completarEntrega(idViaje);
    }

    /** Foto, hora y GPS de la entrega, escritos sobre el pedido releido despues del UPDATE condicional. */
    private void registrarEvidenciaEntrega(Long idSolicitud, String rutaFoto, Point ubicacion, String receptor) {
        DatosEntrega actualizada = datosEntregaRepository.findBySolicitudId(idSolicitud)
                .orElseThrow(() -> new NegocioException("El pedido ya no existe"));
        actualizada.setFotoEntregaUrl(rutaFoto);
        actualizada.setFechaEntrega(LocalDateTime.now());
        actualizada.setUbicacionEntrega(ubicacion);
        actualizada.setReceptorIdentificado(receptor);
        datosEntregaRepository.save(actualizada);
    }

    private ViajeResponse completarEntrega(Long idViaje) {
        ViajeResponse respuesta = viajeService.finalizarDesdeEntrega(idViaje, new FinalizarViajeRequest(null));
        avisarCliente(idViaje, "PAQUETE_ENTREGADO", "Tu paquete fue entregado",
                " confirmó la entrega con una foto.");
        actualizarConstancia(idViaje);
        return respuesta;
    }

    // ---------------------------------------------------------------- espera en el punto de entrega

    /**
     * El repartidor llego al punto de entrega (B) con el pedido en mano: es el primer aviso. Al cliente
     * le suena el mismo aviso del taxi que llego. Se confirma con el GPS a 100 m o menos de B.
     */
    @Transactional
    public ViajeResponse llegadaEntrega(Long idViaje, LlegadaEntregaRequest request) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        if (datos.getEstadoEntrega() != EstadoEntrega.EN_MANO) {
            throw new NegocioException("Primero recoge el pedido");
        }
        if (datos.getFechaLlegadaEntrega() != null) {
            throw new NegocioException("Ya marcaste que llegaste al punto de entrega");
        }
        exigirCercaDelDestino(viaje, request == null ? null : request.latitud(),
                request == null ? null : request.longitud());
        LocalDateTime ahora = LocalDateTime.now();
        datos.setFechaLlegadaEntrega(ahora);
        datos.setAvisosEntrega(1);
        datos.setUltimoAvisoEntrega(ahora);
        datosEntregaRepository.save(datos);
        avisarEsperaEntrega(viaje, datos, 1);
        actualizarConstancia(idViaje);
        return viajeService.obtener(idViaje);
    }

    /**
     * Nuevo aviso "te estoy esperando" en el punto de entrega, con 1 minuto entre cada uno. Despues del
     * tercero el repartidor puede reportar que no pudo entregar (noSePudoEntregar) o seguir esperando,
     * hasta {@link EsperaPasajeroService#LIMITE_AVISOS} avisos.
     */
    @Transactional
    public ViajeResponse avisarDeNuevoEnEntrega(Long idViaje) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        if (datos.getEstadoEntrega() != EstadoEntrega.EN_MANO || datos.getFechaLlegadaEntrega() == null) {
            throw new NegocioException("Marca primero que llegaste al punto de entrega");
        }
        int avisos = datos.getAvisosEntrega() == null ? 1 : datos.getAvisosEntrega();
        if (avisos >= EsperaPasajeroService.LIMITE_AVISOS) {
            throw new NegocioException("Ya avisaste " + EsperaPasajeroService.LIMITE_AVISOS
                    + " veces: llama o reporta que no pudiste entregar");
        }
        LocalDateTime ultimo = datos.getUltimoAvisoEntrega();
        if (ultimo != null) {
            long faltan = EsperaPasajeroService.ESPERA_ENTRE_AVISOS
                    .minus(java.time.Duration.between(ultimo, LocalDateTime.now())).toSeconds();
            if (faltan > 0) {
                throw new NegocioException("Podrás avisar de nuevo en " + faltan + " s");
            }
        }
        datos.setAvisosEntrega(avisos + 1);
        datos.setUltimoAvisoEntrega(LocalDateTime.now());
        datosEntregaRepository.save(datos);
        avisarEsperaEntrega(viaje, datos, avisos + 1);
        return viajeService.obtener(idViaje);
    }

    /** Push "REPARTIDOR_EN_ENTREGA" con el numero del aviso: la app hace sonar el aviso del taxi que llego. */
    private void avisarEsperaEntrega(Viaje viaje, DatosEntrega datos, int aviso) {
        java.util.Map<String, String> extra = java.util.Map.of("aviso", String.valueOf(aviso));
        String receptor = datos.getTipoEnvio() == TipoEnvio.ENCOMIENDA ? primerNombre(datos.getNombreReceptor()) : null;
        if (receptor != null) {
            viajeService.avisarPasajero(viaje, "REPARTIDOR_EN_ENTREGA",
                    "Avísale a " + receptor + ": su paquete llegó",
                    " está en el punto de entrega" + ViajeService.textoAviso(aviso) + ".", extra);
        } else {
            viajeService.avisarPasajero(viaje, "REPARTIDOR_EN_ENTREGA",
                    aviso == 1 ? "Tu repartidor llegó con tu pedido" : "Tu repartidor te está esperando",
                    " te espera en el punto de entrega" + ViajeService.textoAviso(aviso) + ".", extra);
        }
    }

    private static String primerNombre(String nombre) {
        return nombre == null || nombre.isBlank() ? null : ViajeService.primerNombre(nombre);
    }

    // ---------------------------------------------------------------- fallo de entrega

    /**
     * "No se pudo entregar": el repartidor ya tiene el pedido pero no pudo entregarlo (receptor
     * ausente, se niega a pagar, direccion imposible). Exige foto y motivo porque es un incidente que
     * el administrador resuelve con el reporte, y cancela sin republicar: otro repartidor no debe
     * tomar el mismo pedido. El costo real del producto ya pagado se conserva para resolverlo.
     */
    @Transactional
    public ViajeResponse noSePudoEntregar(Long idViaje, String motivo, MultipartFile foto) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        if (datos.getEstadoEntrega() != EstadoEntrega.EN_MANO) {
            throw new NegocioException("Solo se puede reportar la falla cuando el pedido ya esta en tus manos");
        }
        if (motivo == null || motivo.isBlank()) {
            throw new NegocioException("Describe el motivo por el que no pudiste entregar");
        }
        byte[] contenido = imagenOpcional(foto, "La foto de la falla");
        if (contenido == null) {
            throw new NegocioException("La foto es obligatoria para reportar una falla");
        }

        Long idDatos = datos.getId();
        String rutaFoto = guardarEvidencia(contenido, viaje, "falla_entrega");
        String motivoNormalizado = motivo.trim();
        int filas = datosEntregaRepository.registrarFallaSiEstadoPermitido(idDatos, CON_PEDIDO_EN_MANO,
                EstadoEntrega.NO_ENTREGADO, motivoNormalizado, rutaFoto);
        if (filas == 0) {
            throw transicionRechazada(idDatos, CON_PEDIDO_EN_MANO, EstadoEntrega.NO_ENTREGADO,
                    "El pedido ya no esta en tus manos");
        }

        crearReporteFalla(viaje, motivoNormalizado);

        ViajeResponse respuesta = viajeService.cancelarFallaEntrega(idViaje);
        actualizarConstancia(idViaje);
        return respuesta;
    }

    /** Rechaza antes de recoger un paquete que no coincide y deja una advertencia administrativa. */
    @Transactional
    public ViajeResponse reportarPaqueteIncorrecto(Long idViaje, String motivo, MultipartFile foto) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        if (!ANTES_DE_TENER_EL_PEDIDO.contains(datos.getEstadoEntrega())) {
            throw new NegocioException("El paquete solo se puede rechazar antes de recogerlo");
        }
        if (motivo == null || motivo.isBlank()) {
            throw new NegocioException("Describe por que el paquete no coincide");
        }
        byte[] contenido = imagenOpcional(foto, "La foto del paquete");
        if (contenido == null) {
            throw new NegocioException("La foto del paquete es obligatoria");
        }
        datos.setFotoFallaUrl(guardarEvidencia(contenido, viaje, "paquete_no_coincide"));
        datos.setMotivoFalla(motivo.trim());
        datosEntregaRepository.save(datos);
        crearReporte(viaje, "PAQUETE_NO_COINCIDE", motivo.trim());
        ViajeResponse respuesta = viajeService.cancelarFallaEntrega(idViaje);
        actualizarConstancia(idViaje);
        return respuesta;
    }

    // ---------------------------------------------------------------- fotos de la evidencia

    /** Foto de la evidencia de un pedido para el panel admin. */
    @Transactional(readOnly = true)
    public org.springframework.core.io.Resource fotoParaAdmin(Long idViaje, TipoFotoEntrega tipo) {
        DatosEntrega datos = datosDe(viajeService.obtenerParaAdmin(idViaje));
        String ruta = switch (tipo) {
            case RECOGIDA -> datos.getFotoRecogidaUrl();
            case COMPROBANTE -> datos.getFotoComprobanteUrl();
            case ENTREGA -> datos.getFotoEntregaUrl();
            case FALLA -> datos.getFotoFallaUrl();
            case PAQUETE -> datos.getFotoPaqueteUrl();
        };
        return almacenamientoArchivos.leer(ruta);
    }

    /** El cliente ve la foto de su paquete entregado, como confirmacion de que llego. */
    @Transactional(readOnly = true)
    public org.springframework.core.io.Resource fotoEntregaParaCliente(Long idViaje) {
        DatosEntrega datos = datosDe(viajeService.obtenerViajeDelPasajero(idViaje));
        if (datos.getEstadoEntrega() != EstadoEntrega.ENTREGADO || datos.getFotoEntregaUrl() == null) {
            throw new NegocioException("El paquete todavia no fue entregado");
        }
        return almacenamientoArchivos.leer(datos.getFotoEntregaUrl());
    }

    private void crearReporteFalla(Viaje viaje, String motivo) {
        crearReporte(viaje, "FALLA_ENTREGA", motivo);
    }

    private void crearReporte(Viaje viaje, String tipo, String descripcion) {
        if (reporteRepository == null) {
            return;
        }
        Reporte reporte = new Reporte();
        reporte.setViaje(viaje);
        reporte.setUsuarioReporta(viaje.getConductor().getUsuario());
        reporte.setMotivo(tipo);
        reporte.setDescripcion(descripcion);
        reporte.setSituacionReporte(SituacionReporte.PENDIENTE);
        reporte.setFecha(java.time.LocalDateTime.now());
        reporteRepository.save(reporte);
    }

    // ---------------------------------------------------------------- apoyos

    private DatosEntrega datosDe(Viaje viaje) {
        DatosEntrega datos = viaje.getSolicitud() != null ? viaje.getSolicitud().getDatosEntrega() : null;
        if (datos == null) {
            throw new NegocioException("Este viaje no es un pedido DELIVERY");
        }
        return datos;
    }

    private void exigirTipo(DatosEntrega datos, TipoEnvio esperado) {
        if (datos.getTipoEnvio() != esperado) {
            throw new NegocioException("Esta accion es solo para pedidos " + esperado);
        }
    }

    private void exigirEstado(DatosEntrega datos, List<EstadoEntrega> permitidos, EstadoEntrega objetivo) {
        if (!permitidos.contains(datos.getEstadoEntrega())) {
            throw new NegocioException("Transicion de estado no permitida: " + datos.getEstadoEntrega()
                    + " -> " + objetivo);
        }
    }

    private void exigirPagoConfirmado(DatosEntrega datos) {
        if (!Boolean.TRUE.equals(datos.getPagoConfirmado())) {
            throw new NegocioException("Registra primero el pago recibido para completar la entrega");
        }
    }

    /**
     * El UPDATE condicional devuelve 0 tanto si el codigo no coincidia como si el pedido ya habia
     * avanzado. Se relee el estado para no culpar al codigo de una repeticion y para no filtrar en que
     * estado esta el pedido de otro conductor.
     */
    private NegocioException transicionRechazada(Long idDatos, List<EstadoEntrega> permitidos,
            EstadoEntrega objetivo, String mensajeDeCodigo) {
        EstadoEntrega actual = datosEntregaRepository.findById(idDatos)
                .map(DatosEntrega::getEstadoEntrega)
                .orElse(null);
        if (actual == null || !permitidos.contains(actual)) {
            return new NegocioException("Transicion de estado no permitida: " + actual + " -> " + objetivo);
        }
        return new NegocioException(mensajeDeCodigo);
    }

    private void validarReceptor(Viaje viaje, IdentificarReceptorRequest request) {
        Persona persona = receptorEsperado(viaje);
        String nombreEsperado = normalizar(persona.getNombres() + " " + persona.getApellidos());
        if (!normalizar(request.nombre()).equals(nombreEsperado)) {
            throw new NegocioException("El nombre de quien recibio no coincide con el del cliente");
        }
        String telefonoEsperado = persona.getTelefono();
        // Sin telefono registrado solo se valida el nombre: no se puede exigir lo que el cliente dio.
        if (telefonoEsperado == null || telefonoEsperado.isBlank()) {
            return;
        }
        if (!digitos(request.telefono()).equals(digitos(telefonoEsperado))) {
            throw new NegocioException("El telefono de quien recibio no coincide con el del cliente");
        }
    }

    private Persona receptorEsperado(Viaje viaje) {
        if (viaje.getPasajero() == null || viaje.getPasajero().getUsuario() == null
                || viaje.getPasajero().getUsuario().getPersona() == null) {
            throw new NegocioException("El pedido no tiene cliente registrado");
        }
        return viaje.getPasajero().getUsuario().getPersona();
    }

    /** Foto opcional: null cuando no llega archivo, porque el recibo no es obligatorio. */
    private byte[] imagenOpcional(MultipartFile archivo, String nombreCampo) {
        if (archivo == null || archivo.isEmpty()) {
            return null;
        }
        if (archivo.getSize() > AlmacenamientoArchivos.TAMANO_MAXIMO_IMAGEN) {
            throw new NegocioException(nombreCampo + " supera los 5 MB");
        }
        try {
            return ProcesadorImagen.imagenEvidencia(archivo.getBytes());
        } catch (IOException e) {
            throw new NegocioException("No se pudo leer " + nombreCampo.toLowerCase());
        }
    }

    private byte[] imagenObligatoria(MultipartFile archivo, String nombreCampo) {
        byte[] contenido = imagenOpcional(archivo, nombreCampo);
        if (contenido == null) {
            throw new NegocioException(nombreCampo + " es obligatoria");
        }
        return contenido;
    }

    /**
     * Como la foto viene de la app, se guarda con sello de tiempo en la carpeta del viaje: la evidencia
     * no se sobreescribe.
     */
    private String guardarEvidencia(byte[] contenido, Viaje viaje, String nombreBase) {
        Persona persona = viaje.getConductor().getUsuario().getPersona();
        return almacenamientoArchivos.guardarConSello(contenido,
                almacenamientoArchivos.carpetaEntregaViaje(persona, viaje.getId()), nombreBase, "jpg");
    }

    /** La entrega se confirma en B: el GPS del telefono tiene que estar a 100 m o menos del destino. */
    private Point exigirCercaDelDestino(Viaje viaje, Double latitud, Double longitud) {
        Point ubicacion = PuntoDesdeWkt.desdeCoordenadas(latitud, longitud);
        if (ubicacion == null) {
            throw new NegocioException("Activa el GPS: la entrega se confirma con tu ubicacion");
        }
        Point destino = viaje.getDestino();
        if (destino != null) {
            double metros = metrosEntre(latitud, longitud, destino.getY(), destino.getX());
            if (metros > METROS_MAXIMOS_ENTREGA) {
                throw new NegocioException("Estas a " + Math.round(metros) + " m del destino: la entrega se "
                        + "confirma a " + Math.round(METROS_MAXIMOS_ENTREGA) + " m o menos");
            }
        }
        return ubicacion;
    }

    /** Distancia en metros sobre la Tierra (haversine), suficiente para unos cientos de metros. */
    static double metrosEntre(double lat1, double lng1, double lat2, double lng2) {
        double radio = 6_371_000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(Math.toRadians(lat1))
                * Math.cos(Math.toRadians(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return 2 * radio * Math.asin(Math.min(1, Math.sqrt(a)));
    }

    /** Push al cliente con el pedido releido (el UPDATE condicional limpio el contexto). */
    private void avisarCliente(Long idViaje, String tipo, String titulo, String resto) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        if (viaje != null) {
            viajeService.avisarPasajero(viaje, tipo, titulo, resto);
        }
    }

    // ---------------------------------------------------------------- constancia

    /**
     * Reescribe la constancia del pedido (constancia_entrega.txt en la carpeta del viaje) con cada
     * confirmacion hecha hasta ahora: horas, GPS, codigos validados (nunca el codigo), pago, quien
     * recibio y el nombre de cada foto. Se llama despues de cada paso del repartidor.
     */
    private void actualizarConstancia(Long idViaje) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        if (viaje == null || viaje.getSolicitud() == null || viaje.getSolicitud().getDatosEntrega() == null) {
            return;
        }
        DatosEntrega datos = viaje.getSolicitud().getDatosEntrega();
        Persona repartidor = viaje.getConductor().getUsuario().getPersona();
        String ruta = almacenamientoArchivos.carpetaEntregaViaje(repartidor, viaje.getId()) + "/" + NOMBRE_CONSTANCIA;
        almacenamientoArchivos.guardar(textoConstancia(viaje, datos).getBytes(StandardCharsets.UTF_8), ruta);
        if (!ruta.equals(datos.getConstanciaUrl())) {
            datos.setConstanciaUrl(ruta);
            datosEntregaRepository.save(datos);
        }
    }

    static String textoConstancia(Viaje viaje, DatosEntrega datos) {
        StringBuilder t = new StringBuilder();
        t.append("CONSTANCIA DEL PEDIDO DE ENTREGA - UNITAXI\n");
        t.append("Actualizada: ").append(fecha(LocalDateTime.now())).append("\n\n");
        t.append("Viaje N: ").append(viaje.getId());
        if (viaje.getSolicitud() != null) {
            t.append("   Solicitud N: ").append(viaje.getSolicitud().getId());
        }
        t.append("\n");
        t.append("Tipo de envio: ").append(datos.getTipoEnvio()).append("\n");
        t.append("Descripcion: ").append(texto(datos.getDescripcion())).append("\n");
        t.append("Cliente: ").append(nombre(viaje.getPasajero() == null ? null
                : viaje.getPasajero().getUsuario())).append("\n");
        t.append("Repartidor: ").append(nombre(viaje.getConductor().getUsuario()));
        if (viaje.getVehiculo() != null) {
            t.append("   Placa: ").append(texto(viaje.getVehiculo().getPlaca()));
        }
        t.append("\n");
        if (datos.getNombreRemitente() != null || datos.getTelefonoRemitente() != null) {
            t.append("Remitente: ").append(texto(datos.getNombreRemitente())).append(" (")
                    .append(texto(datos.getTelefonoRemitente())).append(")\n");
        }
        if (datos.getNombreReceptor() != null || datos.getTelefonoReceptor() != null) {
            t.append("Receptor: ").append(texto(datos.getNombreReceptor())).append(" (")
                    .append(texto(datos.getTelefonoReceptor())).append(")\n");
        }
        if (viaje.getSolicitud() != null) {
            t.append("Recoger en (A): ").append(texto(viaje.getSolicitud().getOrigenDireccion()))
                    .append(" ").append(coordenadas(viaje.getOrigen())).append("\n");
            t.append("Entregar en (B): ").append(texto(viaje.getSolicitud().getDestinoDireccion()))
                    .append(" ").append(coordenadas(viaje.getDestino())).append("\n");
        }
        t.append("Situacion del viaje: ").append(viaje.getSituacionViaje()).append("\n");
        t.append("Estado de la entrega: ").append(datos.getEstadoEntrega()).append("\n");
        if (viaje.getPrecioFinal() != null) {
            t.append("Precio del servicio: ").append(dinero(viaje.getPrecioFinal())).append(" Bs\n");
        }

        t.append("\nCONFIRMACIONES\n");
        if (viaje.getCreadoEn() != null) {
            t.append("- ").append(fecha(viaje.getCreadoEn())).append("  Pedido aceptado por el repartidor\n");
        }
        if (datos.getFechaLlegadaRecogida() != null) {
            t.append("- ").append(fecha(datos.getFechaLlegadaRecogida()))
                    .append("  Llego al punto de recogida (A)\n");
        }
        if (datos.getTipoEnvio() == TipoEnvio.COMPRA_Y_ENTREGA && datos.getCostoProductoReal() != null) {
            t.append("- ").append(fecha(datos.getFechaRecogida())).append("  Compra registrada en ")
                    .append(texto(datos.getDetalleCompra())).append(" por ").append(dinero(datos.getCostoProductoReal()))
                    .append(" Bs").append(datos.getFotoComprobanteUrl() == null ? ""
                            : " | recibo: " + archivo(datos.getFotoComprobanteUrl()))
                    .append("\n");
        } else if (datos.getFechaRecogida() != null) {
            t.append("- ").append(fecha(datos.getFechaRecogida()))
                    .append("  Paquete recogido con el codigo del remitente validado")
                    .append(" | GPS ").append(coordenadas(datos.getUbicacionRecogida()))
                    .append(" | foto: ").append(archivo(datos.getFotoRecogidaUrl())).append("\n");
        }
        if (Boolean.TRUE.equals(datos.getPagoConfirmado())) {
            t.append("- Pago recibido: ").append(dinero(datos.getMontoPagoRecibido())).append(" Bs (")
                    .append(viaje.getMetodoPago() == null ? "EFECTIVO" : viaje.getMetodoPago()).append(")\n");
        }
        if (datos.getFechaEntrega() != null) {
            t.append("- ").append(fecha(datos.getFechaEntrega())).append("  Paquete entregado")
                    .append(datos.getReceptorIdentificado() == null
                            ? " con el codigo del receptor validado"
                            : " a " + datos.getReceptorIdentificado() + " (cliente identificado)")
                    .append(" | GPS ").append(coordenadas(datos.getUbicacionEntrega()))
                    .append(" | foto: ").append(archivo(datos.getFotoEntregaUrl())).append("\n");
        }
        if (datos.getMotivoFalla() != null) {
            t.append("- ").append(datos.getEstadoEntrega() == EstadoEntrega.NO_ENTREGADO
                    ? "No se pudo entregar: " : "Paquete rechazado: ").append(datos.getMotivoFalla())
                    .append(datos.getFotoFallaUrl() == null ? "" : " | foto: " + archivo(datos.getFotoFallaUrl()))
                    .append("\n");
        }
        if (viaje.getFechaFin() != null) {
            t.append("- ").append(fecha(viaje.getFechaFin())).append("  Viaje completado\n");
        }
        return t.toString();
    }

    private static String nombre(com.taxiuap.backend.identity.entity.Usuario usuario) {
        if (usuario == null || usuario.getPersona() == null) {
            return "-";
        }
        Persona persona = usuario.getPersona();
        return (texto(persona.getNombres()) + " " + texto(persona.getApellidos())).trim();
    }

    private static String fecha(LocalDateTime fecha) {
        return fecha == null ? "-" : fecha.format(FECHA_CONSTANCIA);
    }

    private static String coordenadas(Point punto) {
        return punto == null ? "[sin GPS]" : "[" + punto.getY() + ", " + punto.getX() + "]";
    }

    private static String archivo(String ruta) {
        if (ruta == null) {
            return "-";
        }
        int barra = ruta.lastIndexOf('/');
        return barra < 0 ? ruta : ruta.substring(barra + 1);
    }

    private static String texto(String valor) {
        return valor == null || valor.isBlank() ? "-" : valor.trim();
    }

    private static String textoOpcional(String texto) {
        return texto == null || texto.isBlank() ? null : texto.trim();
    }

    private BigDecimal totalACobrar(DatosEntrega datos, Viaje viaje) {
        BigDecimal producto = datos.getCostoProductoReal() == null ? BigDecimal.ZERO : datos.getCostoProductoReal();
        BigDecimal servicio = viaje.getPrecioFinal();
        if (servicio == null) {
            throw new NegocioException("El viaje todavia no tiene precio de servicio calculado");
        }
        return dinero(producto.add(servicio));
    }

    private static String normalizar(String texto) {
        return texto == null ? "" : texto.trim().replaceAll("\\s+", " ").toLowerCase();
    }

    private static String digitos(String telefono) {
        return telefono == null ? "" : telefono.replaceAll("\\D", "");
    }

    private static BigDecimal dinero(BigDecimal monto) {
        return monto == null ? null : monto.setScale(2, RoundingMode.HALF_UP);
    }
}
