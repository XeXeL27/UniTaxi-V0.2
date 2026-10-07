package com.taxiuap.backend.shared.ia;

/** Una imagen que va en el pedido a la IA, con su tipo (image/jpeg, image/png). */
public record ImagenIa(byte[] bytes, String tipoMime) {
}
