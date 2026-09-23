import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/formato.dart';
import '../archivos_web.dart';
import 'columna_tabla.dart';

enum FormatoExportacion { excel, csv, pdf }

/// Exporta las filas visibles de una tabla (ya filtradas y ordenadas) a Excel, CSV o PDF.
class Exportador {
  static Future<void> exportar<T>({
    required FormatoExportacion formato,
    required String titulo,
    required String nombreArchivo,
    required List<ColumnaTabla<T>> columnas,
    required List<T> filas,
  }) async {
    final marca = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final base = '${nombreArchivo}_$marca';
    switch (formato) {
      case FormatoExportacion.excel:
        descargarArchivo(
          _excel(titulo, columnas, filas),
          '$base.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      case FormatoExportacion.csv:
        descargarArchivo(_csv(columnas, filas), '$base.csv', 'text/csv;charset=utf-8');
      case FormatoExportacion.pdf:
        descargarArchivo(await _pdf(titulo, columnas, filas), '$base.pdf', 'application/pdf');
    }
  }

  static Uint8List _excel<T>(String titulo, List<ColumnaTabla<T>> columnas, List<T> filas) {
    final libro = xl.Excel.createExcel();
    final nombreHoja = titulo.length > 31 ? titulo.substring(0, 31) : titulo;
    libro.rename(libro.getDefaultSheet()!, nombreHoja);
    final hoja = libro[nombreHoja];

    hoja.appendRow([for (final c in columnas) xl.TextCellValue(c.titulo)]);
    final estiloEncabezado = xl.CellStyle(
      bold: true,
      fontColorHex: xl.ExcelColor.white,
      backgroundColorHex: xl.ExcelColor.fromHexString('#0B2341'),
    );
    for (var i = 0; i < columnas.length; i++) {
      hoja.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = estiloEncabezado;
      hoja.setColumnWidth(i, 20);
    }

    for (final fila in filas) {
      hoja.appendRow([for (final c in columnas) _celdaExcel(c, fila)]);
    }
    return Uint8List.fromList(libro.encode()!);
  }

  static xl.CellValue? _celdaExcel<T>(ColumnaTabla<T> columna, T fila) {
    final valor = columna.valor(fila);
    if (valor == null) return null;
    if (columna.tipo == TipoColumna.numero && valor is num) {
      return valor is int ? xl.IntCellValue(valor) : xl.DoubleCellValue(valor.toDouble());
    }
    return xl.TextCellValue(columna.texto(fila));
  }

  /// CSV segun RFC 4180, con BOM para que Excel reconozca UTF-8 (acentos y enie).
  static Uint8List _csv<T>(List<ColumnaTabla<T>> columnas, List<T> filas) {
    String escapar(String valor) {
      if (valor.contains(RegExp(r'[",\r\n]'))) return '"${valor.replaceAll('"', '""')}"';
      return valor;
    }

    final lineas = <String>[
      columnas.map((c) => escapar(c.titulo)).join(','),
      for (final fila in filas) columnas.map((c) => escapar(c.texto(fila))).join(','),
    ];
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(lineas.join('\r\n'))]);
  }

  static Future<Uint8List> _pdf<T>(String titulo, List<ColumnaTabla<T>> columnas, List<T> filas) async {
    final normal = pw.Font.ttf(await rootBundle.load('assets/fuentes/DejaVuSans.ttf'));
    final negrita = pw.Font.ttf(await rootBundle.load('assets/fuentes/DejaVuSans-Bold.ttf'));
    const azul = PdfColor.fromInt(0xFF0B2341);
    const rojo = PdfColor.fromInt(0xFFB71234);

    final documento = pw.Document(title: titulo, author: 'TaxiUAP');
    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: normal, bold: negrita),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 6),
          margin: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: rojo, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TaxiUAP - $titulo',
                style: pw.TextStyle(font: negrita, fontSize: 14, color: azul),
              ),
              pw.Text(
                'Generado: ${Formato.fechaHora(DateTime.now())}  |  ${filas.length} registros',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        footer: (contexto) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${contexto.pageNumber} de ${contexto.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: [for (final c in columnas) c.titulo],
            data: [
              for (final fila in filas) [for (final c in columnas) c.texto(fila)],
            ],
            headerStyle: pw.TextStyle(font: negrita, fontSize: 8, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: azul),
            cellStyle: const pw.TextStyle(fontSize: 8),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F6F9)),
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            headerAlignment: pw.Alignment.centerLeft,
            defaultColumnWidth: const pw.FlexColumnWidth(),
          ),
        ],
      ),
    );
    return documento.save();
  }
}
