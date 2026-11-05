package com.taxiuap.backend.trip.service;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import lombok.extern.slf4j.Slf4j;

import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.communication.entity.Reporte;
import com.taxiuap.backend.communication.enums.SituacionReporte;
import com.taxiuap.backend.communication.repository.ReporteRepository;
import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.service.CalculoPrecioDeliveryService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.archivo.ProcesadorImagen;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.dto.AceptarCostoRequest;
import com.taxiuap.backend.trip.dto.ConfirmarPagoEntregaRequest;
import com.taxiuap.backend.trip.dto.EntregarPedidoRequest;
import com.taxiuap.backend.trip.dto.FinalizarViajeRequest;
import com.taxiuap.backend.trip.dto.IdentificarReceptorRequest;
import com.taxiuap.backend.trip.dto.ProductoCompradoRequest;
import com.taxiuap.backend.trip.dto.PropuestaCostoResponse;
import com.taxiuap.backend.trip.dto.RecogerPaqueteRequest;
import com.taxiuap.backend.trip.dto.RegistrarCompraRequest;
import com.taxiuap.backend.trip.dto.ValidarCodigoEntregaRequest;
import com.taxiuap.backend.trip.dto.LlegadaEntregaRequest;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.ProductoEntrega;
import com.taxiuap.backend.trip.entity.PropuestaCostoEntrega;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.MotivoFallaEntrega;
import com.taxiuap.backend.trip.enums.SituacionProducto;
import com.taxiuap.backend.trip.enums.SituacionPropuestaCosto;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.enums.TipoEnvio;
import com.taxiuap.backend.trip.enums.TipoFotoEntrega;
import com.taxiuap.backend.trip.repository.DatosEntregaRepository;
import com.taxiuap.backend.trip.repository.ProductoEntregaRepository;
import com.taxiuap.backend.trip.repository.PropuestaCostoEntregaRepository;

/**
 * Acciones propias de DELIVERY. ViajeService mantiene el ciclo del viaje (aceptar, cancelar,
 * finalizar) y aqui vive lo que un taxi no tiene: validar los codigos que dicta cada parte, coordinar
 * la compra con el cliente y registrar el pago directo del producto.
 *
 * <p>Todas las transiciones se aplican con UPDATE condicional sobre {@code estado_entrega} (y el codigo
 * cuando aplica), de modo que una doble pulsacion o dos pantallas simultaneas no puedan hacer avanzar el
 * pedido dos veces: la segunda no actualiza ninguna fila.</p>
 */
@Slf4j
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
    private final ProductoEntregaRepository productoEntregaRepository;
    private final PropuestaCostoEntregaRepository propuestaCostoRepository;

    @org.springframework.beans.factory.annotation.Autowired
    public EntregaService(ViajeService viajeService,
            DatosEntregaRepository datosEntregaRepository,
            CalculoPrecioDeliveryService calculoPrecioDeliveryService,
            AlmacenamientoArchivos almacenamientoArchivos, ReporteRepository reporteRepository,
            ProductoEntregaRepository productoEntregaRepository,
            PropuestaCostoEntregaRepository propuestaCostoRepository) {
        this.viajeService = viajeService;
        this.datosEntregaRepository = datosEntregaRepository;
        this.calculoPrecioDeliveryService = calculoPrecioDeliveryService;
        this.almacenamientoArchivos = almacenamientoArchivos;
        this.reporteRepository = reporteRepository;
        this.productoEntregaRepository = productoEntregaRepository;
        this.propuestaCostoRepository = propuestaCostoRepository;
    }

    /** Constructor para pruebas unitarias del flujo DELIVERY que no tocan la compra. */
    public EntregaService(ViajeService viajeService, DatosEntregaRepository datosEntregaRepository,
            CalculoPrecioDeliveryService calculoPrecioDeliveryService,
            AlmacenamientoArchivos almacenamientoArchivos, ReporteRepository reporteRepository) {
        this(viajeService, datosEntregaRepository, calculoPrecioDeliveryService, almacenamientoArchivos,
                reporteRepository, null, null);
    }

    /** Constructor de compatibilidad para pruebas unitarias antiguas del flujo DELIVERY. */
    public EntregaService(ViajeService viajeService, DatosEntregaRepository datosEntregaRepository,
            CalculoPrecioDeliveryService calculoPrecioDeliveryService,
            AlmacenamientoArchivos almacenamientoArchivos) {
        this(viajeService, datosEntregaRepository, calculoPrecioDeliveryService, almacenamientoArchivos, null);
    }

    // ---------------------------------------------------------------- COMPRA_Y_ENTREGA: la compra

    /** Mensaje para las apps de antes de la lista de productos (proponer y confirmar compra ya no existen). */
    public static final String MENSAJE_ACTUALIZAR_COMPRA = "Actualiza UNITAXI: ahora el repartidor registra el "
            + "precio de cada producto al comprar y el cliente acepta el costo total";

    /** Proponer y confirmar la compra antes de comprar ya no existen: se acepta el costo total despues. */
    public ViajeResponse compraConFlujoAnterior() {
        throw new NegocioException(MENSAJE_ACTUALIZAR_COMPRA);
    }

    /**
     * COMPRA_Y_ENTREGA: el repartidor compro y registra cada producto del pedido (conseguido con cantidad y
     * precio unitario, o no conseguido). El servidor calcula subtotales y total; nada del monto llega
     * calculado de la app. La primera vez el pedido pasa a EN_MANO y el precio del servicio se fija desde
     * el comercio hasta el destino con la tarifa del pedido; despues, antes del pago, sirve para corregir
     * precios. Cada registro crea una nueva version del costo total y deja sin efecto la anterior (aunque
     * el cliente ya la hubiera aceptado): el cliente tiene que aceptar de nuevo.
     */
    @Transactional
    public ViajeResponse registrarCompra(Long idViaje, RegistrarCompraRequest request, MultipartFile comprobante) {
        if (request.productos() == null || request.productos().isEmpty()) {
            throw new NegocioException(MENSAJE_ACTUALIZAR_COMPRA);
        }
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.COMPRA_Y_ENTREGA);
        boolean correccion = datos.getEstadoEntrega() == EstadoEntrega.EN_MANO;
        if (!correccion) {
            exigirEstado(datos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO);
        } else if (Boolean.TRUE.equals(datos.getPagoConfirmado())) {
            throw new NegocioException("El pago ya fue confirmado: ya no puedes cambiar los precios");
        }
        List<ProductoEntrega> productos = productoEntregaRepository
                .findByDatosEntregaIdAndEstadoProductoEntregaOrderByOrdenAscIdAsc(datos.getId(), EstadoRegistro.A);
        Map<Long, ProductoCompradoRequest> comprados = productosComprados(productos, request.productos());

        // El comprobante se procesa antes de tocar el estado: si la imagen no sirve, el pedido no avanza.
        byte[] contenidoComprobante = imagenOpcional(comprobante, "El comprobante");
        Point puntoCompra = PuntoDesdeWkt.convertir(request.puntoCompraWkt());
        Long idSolicitud = viaje.getSolicitud().getId();
        Point destino = viaje.getDestino();
        Long idDatos = datos.getId();
        // El recibo se escribe antes del UPDATE: despues, el viaje ya no esta en el contexto de persistencia.
        String rutaComprobante = contenidoComprobante == null ? null
                : guardarEvidencia(contenidoComprobante, viaje, "comprobante_compra");

        int filas = correccion
                ? datosEntregaRepository.invalidarAprobacionSiSinPago(idDatos)
                : datosEntregaRepository.avanzarSiEstadoPermitido(idDatos, ANTES_DE_TENER_EL_PEDIDO,
                        EstadoEntrega.EN_MANO);
        if (filas == 0) {
            if (correccion) {
                throw new NegocioException("El pago ya fue confirmado: ya no puedes cambiar los precios");
            }
            throw transicionRechazada(idDatos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO,
                    "El pedido ya no se puede comprar");
        }

        // El UPDATE condicional limpio el contexto de persistencia: se relee el pedido antes de escribir.
        DatosEntrega actualizada = datosEntregaRepository.findBySolicitudId(idSolicitud)
                .orElseThrow(() -> new NegocioException("El pedido ya no existe"));
        List<PropuestaCostoResponse.LineaCosto> lineas = new ArrayList<>();
        BigDecimal totalProductos = BigDecimal.ZERO.setScale(2);
        for (ProductoEntrega producto : productoEntregaRepository
                .findByDatosEntregaIdAndEstadoProductoEntregaOrderByOrdenAscIdAsc(idDatos, EstadoRegistro.A)) {
            ProductoCompradoRequest comprado = comprados.get(producto.getId());
            String nota = textoOpcional(comprado.observacion());
            producto.setObservacion(nota);
            if (Boolean.TRUE.equals(comprado.conseguido())) {
                // El repartidor escribe lo que pago por todas las unidades; las apps de antes, el precio unitario.
                BigDecimal subtotal = comprado.precioTotal() != null
                        ? dinero(comprado.precioTotal())
                        : dinero(comprado.precioUnitario().multiply(BigDecimal.valueOf(comprado.cantidad())));
                BigDecimal precio = comprado.precioTotal() != null
                        ? subtotal.divide(BigDecimal.valueOf(comprado.cantidad()), 2, RoundingMode.HALF_UP)
                        : dinero(comprado.precioUnitario());
                producto.setSituacionProducto(SituacionProducto.CONSEGUIDO);
                producto.setCantidadConseguida(comprado.cantidad());
                producto.setPrecioUnitario(precio);
                producto.setSubtotal(subtotal);
                totalProductos = totalProductos.add(subtotal);
                lineas.add(new PropuestaCostoResponse.LineaCosto(producto.getNombre(), comprado.cantidad(), precio,
                        subtotal, true, nota));
            } else {
                producto.setSituacionProducto(SituacionProducto.NO_CONSEGUIDO);
                producto.setCantidadConseguida(null);
                producto.setPrecioUnitario(null);
                producto.setSubtotal(BigDecimal.ZERO.setScale(2));
                lineas.add(new PropuestaCostoResponse.LineaCosto(producto.getNombre(), producto.getCantidad(), null,
                        BigDecimal.ZERO.setScale(2), false, nota));
            }
            productoEntregaRepository.save(producto);
        }
        // El comercio y la observacion ya no se piden (la app nueva no los manda; las de antes si).
        actualizada.setDetalleCompra(textoOpcional(request.detalleCompra()));
        actualizada.setCostoProductoReal(totalProductos);
        actualizada.setObservacionCompra(textoOpcional(request.observacionCompra()));
        if (rutaComprobante != null) {
            actualizada.setFotoComprobanteUrl(rutaComprobante);
        }
        if (!correccion) {
            // El servicio se cobra desde el comercio: el punto de compra queda fijo con la primera compra.
            actualizada.setPuntoCompra(puntoCompra);
            actualizada.setFechaRecogida(LocalDateTime.now());
            // Lo unico que vale es aceptar el costo total que se presenta ahora (nada confirmado de antes).
            actualizada.setCompraConfirmadaPorCliente(false);
            actualizada.setCostoProductoConfirmado(null);
        }
        datosEntregaRepository.save(actualizada);

        if (!correccion) {
            DesglosePrecioDelivery precio = calculoPrecioDeliveryService.fijarPrecioCompra(puntoCompra, destino,
                    calculoPrecioDeliveryService.tarifaDe(actualizada));
            viajeService.registrarPedidoEnMano(idViaje, precio);
        }
        // La version anterior se reemplaza antes de releer el viaje: el UPDATE condicional limpia el
        // contexto de persistencia y dejaria al viaje ya leido sin sesion.
        int anterior = propuestaCostoRepository.findFirstByDatosEntregaIdOrderByVersionDesc(idDatos)
                .map(PropuestaCostoEntrega::getVersion)
                .orElse(0);
        propuestaCostoRepository.reemplazarVigentes(idDatos,
                List.of(SituacionPropuestaCosto.PENDIENTE, SituacionPropuestaCosto.ACEPTADA));
        Viaje conPrecio = viajeService.obtenerViajeDelConductor(idViaje);
        PropuestaCostoEntrega propuesta = nuevaPropuesta(conPrecio, idDatos, anterior + 1, totalProductos, lineas);
        log.info("Compra del viaje {} {}: version {} del costo, productos {} Bs, total {} Bs", idViaje,
                correccion ? "corregida" : "registrada", propuesta.getVersion(), totalProductos, propuesta.getTotal());
        viajeService.avisarPasajero(conPrecio, "COSTO_POR_APROBAR",
                correccion ? "El costo de tu compra cambió" : "Revisa el costo de tu compra",
                " registró la compra: " + dinero(propuesta.getTotal()) + " Bs en total. Acéptalo para recibir tu pedido.",
                Map.of("version", String.valueOf(propuesta.getVersion())));
        actualizarConstancia(idViaje);
        return viajeService.obtener(idViaje);
    }

    /**
     * El repartidor debe responder por cada producto del pedido, una sola vez, y conseguir al menos uno: si
     * no consiguio nada no hay compra que cobrar (avisa por el chat o reporta el pedido).
     */
    private static Map<Long, ProductoCompradoRequest> productosComprados(List<ProductoEntrega> productos,
            List<ProductoCompradoRequest> enviados) {
        Map<Long, ProductoCompradoRequest> porId = new HashMap<>();
        for (ProductoCompradoRequest enviado : enviados) {
            if (porId.put(enviado.idProducto(), enviado) != null) {
                throw new NegocioException("Un producto aparece dos veces en la compra");
            }
        }
        Set<Long> delPedido = productos.stream().map(ProductoEntrega::getId).collect(Collectors.toSet());
        if (productos.isEmpty() || !porId.keySet().equals(delPedido)) {
            throw new NegocioException("Registra cada producto del pedido: conseguido con su precio o no conseguido");
        }
        if (enviados.stream().noneMatch(p -> Boolean.TRUE.equals(p.conseguido()))) {
            throw new NegocioException("No conseguiste ningún producto: avísale al cliente por el chat o reporta el pedido");
        }
        return porId;
    }

    /** La nueva version del costo total, PENDIENTE (la anterior ya quedo REEMPLAZADA). */
    private PropuestaCostoEntrega nuevaPropuesta(Viaje viaje, Long idDatos, int version, BigDecimal totalProductos,
            List<PropuestaCostoResponse.LineaCosto> lineas) {
        BigDecimal servicio = viaje.getPrecioFinal();
        if (servicio == null) {
            throw new NegocioException("El viaje todavia no tiene precio de servicio calculado");
        }
        PropuestaCostoEntrega propuesta = new PropuestaCostoEntrega();
        propuesta.setDatosEntrega(datosEntregaRepository.getReferenceById(idDatos));
        propuesta.setViaje(viaje);
        propuesta.setConductor(viaje.getConductor());
        propuesta.setVersion(version);
        propuesta.setPrecioServicio(dinero(servicio));
        propuesta.setTotalProductos(dinero(totalProductos));
        propuesta.setTotal(dinero(servicio.add(totalProductos)));
        propuesta.setDetalleJson(PropuestaCostoResponse.aJson(lineas));
        propuesta.setSituacionPropuesta(SituacionPropuestaCosto.PENDIENTE);
        propuesta.setFechaPropuesta(LocalDateTime.now());
        return propuestaCostoRepository.save(propuesta);
    }

    /**
     * "ACEPTO EL COSTO TOTAL": solo el cliente del pedido y solo la version que vio. Si el repartidor la
     * corrigio mientras tanto, responde 409 con el aviso de revisar el nuevo total. Dos toques seguidos no
     * aceptan dos veces: el segundo encuentra la misma version ya aceptada y no hace nada.
     */
    @Transactional
    public ViajeResponse aceptarCosto(Long idViaje, AceptarCostoRequest request) {
        Viaje viaje = viajeService.obtenerViajeDelPasajero(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.COMPRA_Y_ENTREGA);
        PropuestaCostoEntrega vigente = propuestaCostoRepository
                .findFirstByDatosEntregaIdOrderByVersionDesc(datos.getId())
                .orElseThrow(() -> new NegocioException("El repartidor todavía no registró el costo de tu compra"));
        if (!vigente.getVersion().equals(request.version())) {
            throw new ConflictoException("El costo de tu compra cambió: revisa el nuevo total antes de aceptarlo");
        }
        if (vigente.getSituacionPropuesta() == SituacionPropuestaCosto.ACEPTADA) {
            return viajeService.obtener(idViaje);
        }
        if (Boolean.TRUE.equals(datos.getPagoConfirmado())) {
            throw new NegocioException("El pago ya fue confirmado");
        }
        Long idPropuesta = vigente.getId();
        Long idDatos = datos.getId();
        BigDecimal totalProductos = vigente.getTotalProductos();
        BigDecimal total = vigente.getTotal();
        if (propuestaCostoRepository.aceptarSiPendiente(idPropuesta, viaje.getPasajero().getUsuario(),
                LocalDateTime.now()) == 0) {
            throw new ConflictoException("El costo de tu compra cambió: revisa el nuevo total antes de aceptarlo");
        }
        if (datosEntregaRepository.marcarCostoAprobado(idDatos, totalProductos) == 0) {
            throw new NegocioException("El pago ya fue confirmado");
        }
        Viaje actualizado = viajeService.obtenerViajeDelPasajero(idViaje);
        log.info("Costo total del viaje {} aceptado por el cliente (version {}, {} Bs)", idViaje,
                request.version(), total);
        viajeService.avisarConductor(actualizado, "COSTO_ACEPTADO", "El cliente aceptó el costo",
                "Aceptó " + dinero(total) + " Bs en total. Ya puedes llevarle el pedido.");
        return viajeService.obtener(idViaje);
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

    /**
     * ENCOMIENDA: el repartidor ya llego a A y recibe el paquete, sin codigo. La foto del paquete es
     * opcional. El pedido pasa a EN_MANO, el viaje a EN_CURSO y empieza la entrega hacia B.
     */
    @Transactional
    public ViajeResponse recogerPaquete(Long idViaje, RecogerPaqueteRequest request, MultipartFile foto) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.ENCOMIENDA);
        exigirEstado(datos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO);
        if (viaje.getSituacionViaje() != SituacionViaje.CONDUCTOR_LLEGO) {
            throw new NegocioException("Marca primero que llegaste al punto de recogida");
        }
        byte[] contenido = imagenOpcional(foto, "La foto del paquete");
        String rutaFoto = contenido == null ? null : guardarEvidencia(contenido, viaje, "recogida");
        Point ubicacion = request == null ? null : PuntoDesdeWkt.desdeCoordenadas(request.latitud(), request.longitud());
        Long idSolicitud = viaje.getSolicitud().getId();
        Long idDatos = datos.getId();

        int filas = datosEntregaRepository.avanzarSiEstadoPermitido(idDatos, ANTES_DE_TENER_EL_PEDIDO,
                EstadoEntrega.EN_MANO);
        if (filas == 0) {
            throw transicionRechazada(idDatos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO,
                    "El paquete ya no se puede recoger");
        }

        DatosEntrega actualizada = datosEntregaRepository.findBySolicitudId(idSolicitud)
                .orElseThrow(() -> new NegocioException("El pedido ya no existe"));
        actualizada.setFotoRecogidaUrl(rutaFoto);
        actualizada.setFechaRecogida(LocalDateTime.now());
        actualizada.setUbicacionRecogida(ubicacion);
        datosEntregaRepository.save(actualizada);

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
        exigirCostoAceptado(datos);
        if (Boolean.TRUE.equals(viaje.getSolicitud().getPagaSolicitante())
                && request.metodoPago() != null && request.metodoPago() != com.taxiuap.backend.pricing.enums.MetodoPago.QR) {
            throw new NegocioException("Este pedido lo paga quien lo pidió, por QR: no le cobres a quien recibe");
        }

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
            boolean pagado = datosEntregaRepository.findById(datos.getId())
                    .map(d -> Boolean.TRUE.equals(d.getPagoConfirmado())).orElse(false);
            // Una compra sin pagar que no avanzo: el repartidor corrigio los precios al mismo tiempo.
            throw new NegocioException(pagado ? "El pago ya fue confirmado" : MENSAJE_COSTO_SIN_ACEPTAR);
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
        exigirCostoAceptado(datos);
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

    /**
     * Entrega en B (paquete o delivery), sin codigo ni foto: el pago ya confirmado, el costo aceptado en
     * una compra y el GPS a 100 m o menos del destino. Si recibe otra persona, el nombre completo que
     * ella le dice al repartidor tiene que ser el que dio el cliente; si recibe el cliente, nada mas.
     */
    @Transactional
    public ViajeResponse entregarPedido(Long idViaje, EntregarPedidoRequest request) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirEstado(datos, CON_PEDIDO_EN_MANO, EstadoEntrega.ENTREGADO);
        exigirCostoAceptado(datos);
        exigirPagoConfirmado(datos);
        String recibe = validarNombreDeQuienRecibe(viaje, datos, request.nombreReceptor());
        Point ubicacion = exigirCercaDelDestino(viaje, request.latitud(), request.longitud());
        Long idSolicitud = viaje.getSolicitud().getId();

        int filas = datosEntregaRepository.avanzarSiEstadoPermitido(datos.getId(), CON_PEDIDO_EN_MANO,
                EstadoEntrega.ENTREGADO);
        if (filas == 0) {
            throw transicionRechazada(datos.getId(), CON_PEDIDO_EN_MANO, EstadoEntrega.ENTREGADO,
                    "El pedido ya no se puede entregar");
        }

        registrarEvidenciaEntrega(idSolicitud, null, ubicacion, recibe);
        return completarEntrega(idViaje);
    }

    /**
     * Nombre de quien recibe para la constancia. Con otra persona (pedido para otra persona o, en una
     * encomienda de antes, el receptor escrito) exige su nombre completo y lo compara con el que dio el
     * cliente; si recibe el cliente devuelve su nombre registrado.
     */
    private String validarNombreDeQuienRecibe(Viaje viaje, DatosEntrega datos, String escrito) {
        String esperado = nombreDeOtraPersona(viaje, datos);
        if (esperado == null) {
            return nombre(viaje.getPasajero() == null ? null : viaje.getPasajero().getUsuario());
        }
        if (escrito == null || escrito.isBlank()) {
            throw new NegocioException("Pregúntale su nombre completo a quien recibe y escríbelo");
        }
        if (!nombreCoincide(escrito, esperado)) {
            throw new NegocioException("El nombre no coincide con el de quien debe recibir el pedido. "
                    + "Pregúntale su nombre completo y escríbelo como te lo dice");
        }
        return escrito.trim().replaceAll("\\s+", " ").toUpperCase();
    }

    /** Nombre que dio el cliente para quien recibe, o null si recibe el mismo cliente. */
    private static String nombreDeOtraPersona(Viaje viaje, DatosEntrega datos) {
        if (viaje.getSolicitud() != null && viaje.getSolicitud().esParaOtraPersona()) {
            String tercero = viaje.getSolicitud().getNombrePasajeroTercero();
            return tercero == null || tercero.isBlank() ? null : tercero;
        }
        if (datos.getTipoEnvio() == TipoEnvio.ENCOMIENDA && datos.getNombreReceptor() != null
                && !datos.getNombreReceptor().isBlank()) {
            return datos.getNombreReceptor();
        }
        return null;
    }

    /**
     * Cada palabra del nombre que dio el cliente tiene que estar en el que se escribio (sin tildes ni
     * mayusculas): "Juan Perez" acepta "JUAN CARLOS PÉREZ", pero no "Juan Mamani".
     */
    static boolean nombreCoincide(String escrito, String esperado) {
        Set<String> palabras = Set.of(palabrasDeNombre(escrito));
        String[] esperadas = palabrasDeNombre(esperado);
        if (esperadas.length == 0) {
            return false;
        }
        for (String palabra : esperadas) {
            if (!palabras.contains(palabra)) {
                return false;
            }
        }
        return true;
    }

    private static String[] palabrasDeNombre(String nombre) {
        String limpio = java.text.Normalizer.normalize(nombre == null ? "" : nombre, java.text.Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .toUpperCase()
                .replaceAll("[^A-Z]+", " ")
                .trim();
        return limpio.isEmpty() ? new String[0] : java.util.Arrays.stream(limpio.split(" ")).distinct()
                .toArray(String[]::new);
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
        ViajeResponse respuesta = viajeService.finalizarDesdeEntrega(idViaje, FinalizarViajeRequest.sinDatos());
        avisarCliente(idViaje, "PAQUETE_ENTREGADO", "Tu paquete fue entregado",
                " confirmó la entrega.");
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
        String receptor = receptorTercero(viaje, datos);
        if (receptor != null) {
            viajeService.avisarPasajero(viaje, "REPARTIDOR_EN_ENTREGA",
                    "Avísale a " + receptor + (datos.getTipoEnvio() == TipoEnvio.ENCOMIENDA
                            ? ": su paquete llegó" : ": su pedido llegó"),
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

    /**
     * Primer nombre de quien recibe cuando no es el cliente: el pedido para otra persona o, en una
     * encomienda de antes, el receptor que se escribio. null si recibe el mismo cliente.
     */
    private static String receptorTercero(Viaje viaje, DatosEntrega datos) {
        if (viaje.getSolicitud() != null && viaje.getSolicitud().esParaOtraPersona()) {
            return primerNombre(viaje.getSolicitud().getNombrePasajeroTercero());
        }
        return datos.getTipoEnvio() == TipoEnvio.ENCOMIENDA ? primerNombre(datos.getNombreReceptor()) : null;
    }

    // ---------------------------------------------------------------- fallo de entrega

    /** Sin motivo elegido (apps de antes de los motivos): cuenta como "Otro motivo". */
    @Transactional
    public ViajeResponse noSePudoEntregar(Long idViaje, String motivo, MultipartFile foto) {
        return noSePudoEntregar(idViaje, null, motivo, foto);
    }

    /**
     * "No se pudo entregar": el repartidor ya tiene el pedido pero no pudo entregarlo (el cliente no
     * lo recibio, no pago, no acepto el costo total u otro motivo). Exige el mensaje y la foto porque
     * es un incidente que el administrador resuelve con el reporte, y cancela sin republicar: otro
     * repartidor no debe tomar el mismo pedido. El viaje se cierra para los dos (al cliente le llega
     * el aviso) y queda en el historial como no entregado. El costo de lo comprado se conserva.
     */
    @Transactional
    public ViajeResponse noSePudoEntregar(Long idViaje, MotivoFallaEntrega tipo, String motivo, MultipartFile foto) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        if (datos.getEstadoEntrega() != EstadoEntrega.EN_MANO) {
            throw new NegocioException("Solo se puede reportar la falla cuando el pedido ya esta en tus manos");
        }
        MotivoFallaEntrega elegido = tipo == null ? MotivoFallaEntrega.OTRO : tipo;
        if (elegido == MotivoFallaEntrega.NO_APROBO_COSTO && (datos.getTipoEnvio() != TipoEnvio.COMPRA_Y_ENTREGA
                || Boolean.TRUE.equals(datos.getCompraConfirmadaPorCliente()))) {
            throw new NegocioException(datos.getTipoEnvio() == TipoEnvio.COMPRA_Y_ENTREGA
                    ? "El cliente ya aceptó el costo total: elige otro motivo"
                    : "Ese motivo es solo para una compra");
        }
        if (motivo == null || motivo.isBlank()) {
            throw new NegocioException("Escribe qué pasó para que el administrador lo revise");
        }
        byte[] contenido = imagenOpcional(foto, "La foto de la falla");
        if (contenido == null) {
            throw new NegocioException("La foto es obligatoria para reportar una falla");
        }

        Long idDatos = datos.getId();
        String rutaFoto = guardarEvidencia(contenido, viaje, "falla_entrega");
        String motivoNormalizado = motivo.trim();
        int filas = datosEntregaRepository.registrarFallaSiEstadoPermitido(idDatos, CON_PEDIDO_EN_MANO,
                EstadoEntrega.NO_ENTREGADO, elegido, motivoNormalizado, rutaFoto);
        if (filas == 0) {
            throw transicionRechazada(idDatos, CON_PEDIDO_EN_MANO, EstadoEntrega.NO_ENTREGADO,
                    "El pedido ya no esta en tus manos");
        }

        crearReporteFalla(viaje, elegido.texto() + ": " + motivoNormalizado);

        ViajeResponse respuesta = viajeService.cancelarFallaEntrega(idViaje);
        avisarCliente(idViaje, "PEDIDO_NO_ENTREGADO", "Tu pedido se cerró sin entregar",
                " reportó: " + elegido.texto().toLowerCase(java.util.Locale.forLanguageTag("es"))
                        + ". Un administrador lo revisará.");
        actualizarConstancia(idViaje);
        log.info("Pedido del viaje {} reportado como no entregado ({})", idViaje, elegido);
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

    static final String MENSAJE_COSTO_SIN_ACEPTAR =
            "El cliente todavía no aceptó el costo total de la compra: no puedes cobrar ni entregar";

    /** Compra: sin el costo total aceptado por el cliente no se cobra ni se entrega. */
    private void exigirCostoAceptado(DatosEntrega datos) {
        if (datos.getTipoEnvio() == TipoEnvio.COMPRA_Y_ENTREGA
                && !Boolean.TRUE.equals(datos.getCompraConfirmadaPorCliente())) {
            throw new NegocioException(MENSAJE_COSTO_SIN_ACEPTAR);
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
        if (viaje.getSolicitud() != null && viaje.getSolicitud().esParaOtraPersona()) {
            // Para otra persona: el cliente dio el nombre y el celular de quien recibe; el celular manda.
            if (request.nombre() == null || request.nombre().isBlank()) {
                throw new NegocioException("Ingresa el nombre de quien recibió");
            }
            if (!digitos(request.telefono()).equals(digitos(viaje.getSolicitud().getTelefonoPasajeroTercero()))) {
                throw new NegocioException("El celular de quien recibió no coincide con el de "
                        + primerNombre(viaje.getSolicitud().getNombrePasajeroTercero()));
            }
            return;
        }
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
        if (datos.getTipoEnvio() == TipoEnvio.COMPRA_Y_ENTREGA && datos.getProductos() != null) {
            for (ProductoEntrega producto : datos.getProductos()) {
                t.append("  - ").append(producto.getCantidad()).append(" x ").append(producto.getNombre());
                if (producto.getIndicaciones() != null) {
                    t.append(" (").append(producto.getIndicaciones()).append(")");
                }
                if (producto.getSituacionProducto() == SituacionProducto.CONSEGUIDO) {
                    t.append(" | comprado ").append(producto.getCantidadConseguida()).append(" por ")
                            .append(dinero(producto.getSubtotal())).append(" Bs en total");
                } else if (producto.getSituacionProducto() == SituacionProducto.NO_CONSEGUIDO) {
                    t.append(" | no conseguido");
                }
                if (producto.getObservacion() != null) {
                    t.append(" | nota: ").append(producto.getObservacion());
                }
                t.append("\n");
            }
        }
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
            t.append("- ").append(fecha(datos.getFechaRecogida())).append("  Compra registrada")
                    .append(datos.getDetalleCompra() == null ? "" : " en " + texto(datos.getDetalleCompra()))
                    .append(" | GPS ").append(coordenadas(datos.getPuntoCompra()))
                    .append(" por ").append(dinero(datos.getCostoProductoReal()))
                    .append(" Bs").append(datos.getFotoComprobanteUrl() == null ? ""
                            : " | recibo: " + archivo(datos.getFotoComprobanteUrl()))
                    .append("\n");
        } else if (datos.getFechaRecogida() != null) {
            t.append("- ").append(fecha(datos.getFechaRecogida()))
                    .append("  Paquete recogido en el punto de recogida (A)")
                    .append(" | GPS ").append(coordenadas(datos.getUbicacionRecogida()))
                    .append(" | foto: ").append(archivo(datos.getFotoRecogidaUrl())).append("\n");
        }
        if (datos.getTipoEnvio() == TipoEnvio.COMPRA_Y_ENTREGA && datos.getPropuestas() != null) {
            for (PropuestaCostoEntrega propuesta : datos.getPropuestas()) {
                t.append("- ").append(fecha(propuesta.getFechaPropuesta())).append("  Costo total version ")
                        .append(propuesta.getVersion()).append(": servicio ").append(dinero(propuesta.getPrecioServicio()))
                        .append(" + productos ").append(dinero(propuesta.getTotalProductos())).append(" = ")
                        .append(dinero(propuesta.getTotal())).append(" Bs | ").append(propuesta.getSituacionPropuesta());
                if (propuesta.getFechaRespuesta() != null) {
                    t.append(" por el cliente el ").append(fecha(propuesta.getFechaRespuesta()));
                }
                t.append("\n");
            }
        }
        if (Boolean.TRUE.equals(datos.getPagoConfirmado())) {
            t.append("- Pago recibido: ").append(dinero(datos.getMontoPagoRecibido())).append(" Bs (")
                    .append(viaje.getMetodoPago() == null ? "EFECTIVO" : viaje.getMetodoPago()).append(")\n");
        }
        if (datos.getFechaEntrega() != null) {
            t.append("- ").append(fecha(datos.getFechaEntrega())).append("  Paquete entregado")
                    .append(datos.getReceptorIdentificado() == null
                            ? " con el codigo del receptor validado"
                            : " a " + datos.getReceptorIdentificado())
                    .append(" | GPS ").append(coordenadas(datos.getUbicacionEntrega()))
                    .append(" | foto: ").append(archivo(datos.getFotoEntregaUrl())).append("\n");
        }
        if (datos.getMotivoFalla() != null) {
            t.append("- ").append(datos.getEstadoEntrega() == EstadoEntrega.NO_ENTREGADO
                    ? "No se pudo entregar" + (datos.getTipoFalla() == null ? "" : " (" + datos.getTipoFalla().texto() + ")")
                            + ": " : "Paquete rechazado: ").append(datos.getMotivoFalla())
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
