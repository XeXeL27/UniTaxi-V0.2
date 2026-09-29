package com.taxiuap.backend.pricing.dto;

import java.time.LocalDateTime;

/** QR de cobro de un conductor. La imagen se pide aparte (endpoint .../imagen del actor). */
public record QrPagoResponse(Long idQr, int numero, LocalDateTime actualizadoEn) {
}
