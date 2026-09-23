package com.taxiuap.backend.seed;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/**
 * Genera un PDF minimo de una pagina con dos lineas de texto, para que los documentos de los
 * conductores de prueba tengan un archivo real que el panel admin pueda mostrar.
 */
final class PdfEjemploSeed {

    private PdfEjemploSeed() {
    }

    static byte[] generar(String titulo, String detalle) {
        String contenido = "BT /F1 20 Tf 72 740 Td (" + escapar(titulo) + ") Tj ET\n"
                + "BT /F1 12 Tf 72 710 Td (" + escapar(detalle) + ") Tj ET\n"
                + "BT /F1 10 Tf 72 680 Td (Documento de ejemplo generado por el seed de TaxiUAP) Tj ET\n";
        String[] objetos = {
                "<< /Type /Catalog /Pages 2 0 R >>",
                "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
                "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R "
                        + "/Resources << /Font << /F1 5 0 R >> >> >>",
                "<< /Length " + contenido.length() + " >>\nstream\n" + contenido + "endstream",
                "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        };

        StringBuilder pdf = new StringBuilder("%PDF-1.4\n");
        List<Integer> posiciones = new ArrayList<>();
        for (int i = 0; i < objetos.length; i++) {
            posiciones.add(pdf.length());
            pdf.append(i + 1).append(" 0 obj\n").append(objetos[i]).append("\nendobj\n");
        }
        int inicioXref = pdf.length();
        pdf.append("xref\n0 ").append(objetos.length + 1).append("\n0000000000 65535 f \n");
        for (int posicion : posiciones) {
            pdf.append(String.format("%010d 00000 n \n", posicion));
        }
        pdf.append("trailer\n<< /Size ").append(objetos.length + 1).append(" /Root 1 0 R >>\n")
                .append("startxref\n").append(inicioXref).append("\n%%EOF\n");
        return pdf.toString().getBytes(StandardCharsets.US_ASCII);
    }

    /** Solo ASCII: el texto de ejemplo no lleva acentos; se escapan los parentesis y la barra. */
    private static String escapar(String texto) {
        return texto.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)");
    }
}
