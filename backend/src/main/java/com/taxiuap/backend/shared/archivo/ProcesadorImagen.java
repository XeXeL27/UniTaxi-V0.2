package com.taxiuap.backend.shared.archivo;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;

import com.taxiuap.backend.shared.exception.NegocioException;

/**
 * Adapta las fotos de perfil para que siempre calcen en el circulo de las apps: recorta el
 * cuadrado central de la imagen, la reduce a 512 x 512 y la guarda como JPEG. Asi da igual si la
 * foto se saco vertical, horizontal o con otra resolucion.
 */
public final class ProcesadorImagen {

    public static final int LADO_FOTO = 512;
    /** Lado mayor de una imagen de QR: suficiente para escanearla sin guardar fotos enormes. */
    public static final int LADO_MAXIMO_QR = 1200;
    private static final float CALIDAD_JPEG = 0.88f;

    private ProcesadorImagen() {
    }

    public static byte[] fotoPerfil(byte[] original) {
        BufferedImage imagen = leer(original);

        int lado = Math.min(imagen.getWidth(), imagen.getHeight());
        int x = (imagen.getWidth() - lado) / 2;
        int y = (imagen.getHeight() - lado) / 2;

        // Fondo blanco: una PNG con transparencia no queda negra al pasar a JPEG.
        BufferedImage cuadrada = new BufferedImage(LADO_FOTO, LADO_FOTO, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = cuadrada.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        g.setColor(Color.WHITE);
        g.fillRect(0, 0, LADO_FOTO, LADO_FOTO);
        g.drawImage(imagen, 0, 0, LADO_FOTO, LADO_FOTO, x, y, x + lado, y + lado, null);
        g.dispose();

        ImageWriter escritor = ImageIO.getImageWritersByFormatName("jpeg").next();
        ImageWriteParam parametros = escritor.getDefaultWriteParam();
        parametros.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
        parametros.setCompressionQuality(CALIDAD_JPEG);
        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        try (ImageOutputStream flujo = ImageIO.createImageOutputStream(salida)) {
            escritor.setOutput(flujo);
            escritor.write(null, new IIOImage(cuadrada, null, null), parametros);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo procesar la foto", e);
        } finally {
            escritor.dispose();
        }
        return salida.toByteArray();
    }

    /**
     * Imagen del QR de cobro: se conserva entera (sin recortar), se reduce si pasa de
     * {@link #LADO_MAXIMO_QR} y se guarda como PNG para que los modulos del QR queden nitidos.
     */
    public static byte[] imagenQr(byte[] original) {
        BufferedImage imagen = leer(original);
        double escala = Math.min(1.0, (double) LADO_MAXIMO_QR / Math.max(imagen.getWidth(), imagen.getHeight()));
        int ancho = Math.max(1, (int) Math.round(imagen.getWidth() * escala));
        int alto = Math.max(1, (int) Math.round(imagen.getHeight() * escala));

        BufferedImage salidaImagen = new BufferedImage(ancho, alto, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = salidaImagen.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        g.setColor(Color.WHITE);
        g.fillRect(0, 0, ancho, alto);
        g.drawImage(imagen, 0, 0, ancho, alto, null);
        g.dispose();

        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        try {
            ImageIO.write(salidaImagen, "png", salida);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo procesar la imagen del QR", e);
        }
        return salida.toByteArray();
    }

    private static BufferedImage leer(byte[] original) {
        BufferedImage imagen;
        try {
            imagen = ImageIO.read(new ByteArrayInputStream(original));
        } catch (IOException e) {
            imagen = null;
        }
        if (imagen == null) {
            throw new NegocioException("La imagen no es valida. Use una foto JPG o PNG");
        }
        return imagen;
    }
}
