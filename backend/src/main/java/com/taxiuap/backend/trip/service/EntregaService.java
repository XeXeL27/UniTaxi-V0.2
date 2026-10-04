package com.taxiuap.backend.trip.service;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.entity.Persona;
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
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;
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

    private final ViajeService viajeService;
    private final DatosEntregaRepository datosEntregaRepository;
    private final CalculoPrecioDeliveryService calculoPrecioDeliveryService;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    public EntregaService(ViajeService viajeService,
            DatosEntregaRepository datosEntregaRepository,
            CalculoPrecioDeliveryService calculoPrecioDeliveryService,
            AlmacenamientoArchivos almacenamientoArchivos) {
        this.viajeService = viajeService;
        this.datosEntregaRepository = datosEntregaRepository;
        this.calculoPrecioDeliveryService = calculoPrecioDeliveryService;
        this.almacenamientoArchivos = almacenamientoArchivos;
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
     * porque el 0% de comision es solo del servicio.
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
        if (contenidoComprobante != null) {
            actualizada.setFotoComprobanteUrl(guardarEvidencia(contenidoComprobante, viaje, "comprobante_compra"));
        }
        datosEntregaRepository.save(actualizada);

        DesglosePrecioDelivery precio = calculoPrecioDeliveryService.fijarPrecioCompra(puntoCompra, destino);
        return viajeService.registrarPedidoEnMano(idViaje, precio);
    }

    // ---------------------------------------------------------------- ENCOMIENDA: recogida en A

    /**
     * ENCOMIENDA: el repartidor llego a A y el remitente le dicta el codigo de recogida. Con el codigo
     * correcto el pedido pasa a EN_MANO y el viaje a EN_CURSO. El codigo incorrecto no avanza nada y se
     * responde con un mensaje generico, sin decir si el pedido existe o en que estado esta.
     */
    @Transactional
    public ViajeResponse validarRecogida(Long idViaje, ValidarCodigoEntregaRequest request) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.ENCOMIENDA);
        exigirEstado(datos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO);
        Long idDatos = datos.getId();

        int filas = datosEntregaRepository.avanzarSiCodigoRecogidaCoincide(idDatos, ANTES_DE_TENER_EL_PEDIDO,
                EstadoEntrega.EN_MANO, request.codigo());
        if (filas == 0) {
            throw transicionRechazada(idDatos, ANTES_DE_TENER_EL_PEDIDO, EstadoEntrega.EN_MANO,
                    "El codigo de recogida no coincide");
        }

        // El precio no cambia: el codigo de recogida solo confirma la entrega fisica del paquete.
        return viajeService.registrarPedidoEnMano(idViaje, null);
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
     * confirmado y la comision del 0% aplicada solo al servicio, el pedido queda ENTREGADO y el viaje
     * COMPLETADO.
     */
    @Transactional
    public ViajeResponse entregarConCodigo(Long idViaje, ValidarCodigoEntregaRequest request) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.ENCOMIENDA);
        exigirEstado(datos, CON_PEDIDO_EN_MANO, EstadoEntrega.ENTREGADO);
        exigirPagoConfirmado(datos);
        Long idDatos = datos.getId();

        int filas = datosEntregaRepository.avanzarSiCodigoEntregaCoincide(idDatos, CON_PEDIDO_EN_MANO,
                EstadoEntrega.ENTREGADO, request.codigo());
        if (filas == 0) {
            throw transicionRechazada(idDatos, CON_PEDIDO_EN_MANO, EstadoEntrega.ENTREGADO,
                    "El codigo de entrega no coincide");
        }

        return viajeService.finalizarDesdeEntrega(idViaje,
                new FinalizarViajeRequest(null));
    }

    /**
     * COMPRA_Y_ENTREGA: no hay codigo, el receptor siempre es el cliente que creo el pedido. Se
     * comprueba que quien firma sea ese cliente (nombre y, si el cliente tiene telefono registrado,
     * tambien el telefono) para que otra persona no pueda recibir el pedido.
     */
    @Transactional
    public ViajeResponse entregarConReceptor(Long idViaje,
            IdentificarReceptorRequest request) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        DatosEntrega datos = datosDe(viaje);
        exigirTipo(datos, TipoEnvio.COMPRA_Y_ENTREGA);
        exigirEstado(datos, CON_PEDIDO_EN_MANO, EstadoEntrega.ENTREGADO);
        exigirPagoConfirmado(datos);
        validarReceptor(viaje, request);

        int filas = datosEntregaRepository.avanzarSiEstadoPermitido(datos.getId(), CON_PEDIDO_EN_MANO,
                EstadoEntrega.ENTREGADO);
        if (filas == 0) {
            throw transicionRechazada(datos.getId(), CON_PEDIDO_EN_MANO, EstadoEntrega.ENTREGADO,
                    "El pedido ya no se puede entregar");
        }

        return viajeService.finalizarDesdeEntrega(idViaje,
                new FinalizarViajeRequest(null));
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

        return viajeService.cancelarFallaEntrega(idViaje);
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
            return ProcesadorImagen.fotoPerfil(archivo.getBytes());
        } catch (IOException e) {
            throw new NegocioException("No se pudo leer " + nombreCampo.toLowerCase());
        }
    }

    /** Como la foto viene de la app, se guarda con sello de tiempo: la evidencia no se sobreescribe. */
    private String guardarEvidencia(byte[] contenido, Viaje viaje, String nombreBase) {
        Persona persona = viaje.getConductor().getUsuario().getPersona();
        return almacenamientoArchivos.guardarConSello(contenido,
                almacenamientoArchivos.carpetaEntregaConductor(persona), nombreBase, "jpg");
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