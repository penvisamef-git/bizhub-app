import 'dart:convert';
import 'dart:io' show ZLibEncoder;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:share_plus/share_plus.dart';

// Files the note screens hand to the phone's share sheet: CSV (from the API), Excel (.xlsx, built here — the web's
// lib/xlsx.js: a zip of a few XML files, stored) and PDF (pages as pictures, so Khmer always looks right).

// a safe file name: no path characters, dashes as "-", Khmer kept
String ntFileName(String s, String ext) {
  var t = s.replaceAll(RegExp(r'[‐-―−]'), '-').replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length > 80) t = t.substring(0, 80);
  return '${t.isEmpty ? 'note' : t}.$ext';
}

Future<void> ntShareFile(List<int> bytes, String name, String mime) => SharePlus.instance.share(
  ShareParams(files: [XFile.fromData(Uint8List.fromList(bytes), name: name, mimeType: mime)], fileNameOverrides: [name]),
);

Future<void> ntShareCsv(String text, String name) => ntShareFile(utf8.encode(text.startsWith('﻿') ? text : '﻿$text'), name, 'text/csv');

// ---------------------------------------------------------------- zip (stored) + xlsx
final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

Uint8List ntZip(List<(String, List<int>)> files) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  final now = DateTime.now();
  final time = (now.hour << 11) | (now.minute << 5) | (now.second >> 1);
  final date = ((now.year - 1980) << 9) | (now.month << 5) | now.day;
  var offset = 0;
  ByteData d(int len) => ByteData(len);
  for (final (name, data) in files) {
    final nameB = utf8.encode(name);
    final crc = _crc32(data);
    final h = d(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 0x0800, Endian.little)
      ..setUint16(8, 0, Endian.little)
      ..setUint16(10, time, Endian.little)
      ..setUint16(12, date, Endian.little)
      ..setUint32(14, crc, Endian.little)
      ..setUint32(18, data.length, Endian.little)
      ..setUint32(22, data.length, Endian.little)
      ..setUint16(26, nameB.length, Endian.little)
      ..setUint16(28, 0, Endian.little);
    out
      ..add(h.buffer.asUint8List())
      ..add(nameB)
      ..add(data);
    final cd = d(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(8, 0x0800, Endian.little)
      ..setUint16(10, 0, Endian.little)
      ..setUint16(12, time, Endian.little)
      ..setUint16(14, date, Endian.little)
      ..setUint32(16, crc, Endian.little)
      ..setUint32(20, data.length, Endian.little)
      ..setUint32(24, data.length, Endian.little)
      ..setUint16(28, nameB.length, Endian.little)
      ..setUint32(42, offset, Endian.little);
    central
      ..add(cd.buffer.asUint8List())
      ..add(nameB);
    offset += 30 + nameB.length + data.length;
  }
  final cdBytes = central.toBytes();
  final end = d(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(8, files.length, Endian.little)
    ..setUint16(10, files.length, Endian.little)
    ..setUint32(12, cdBytes.length, Endian.little)
    ..setUint32(16, offset, Endian.little);
  out
    ..add(cdBytes)
    ..add(end.buffer.asUint8List());
  return out.toBytes();
}

String _esc(Object? v) => '${v ?? ''}'
    .replaceAll(RegExp(r'[\u0000-\u0008\u000b\u000c\u000e-\u001f]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _col(int i) {
  var s = '';
  var n = i + 1;
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

// one sheet, a bold first row, column widths from the text; numbers stay numbers, the rest is plain text (no formulas)
Uint8List ntXlsx(String sheetName, List<List<Object?>> rows) {
  var name = sheetName.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
  if (name.length > 31) name = name.substring(0, 31);
  if (name.isEmpty) name = 'Sheet1';
  final widths = <int>[];
  for (final r in rows) {
    for (var i = 0; i < r.length; i++) {
      final w = ('${r[i] ?? ''}'.length + 2).clamp(8, 60);
      if (widths.length <= i) {
        widths.add(w);
      } else if (w > widths[i]) {
        widths[i] = w;
      }
    }
  }
  final cols = widths.isEmpty ? '' : '<cols>${[for (var i = 0; i < widths.length; i++) '<col min="${i + 1}" max="${i + 1}" width="${widths[i]}" customWidth="1"/>'].join()}</cols>';
  final sheetRows = StringBuffer();
  for (var ri = 0; ri < rows.length; ri++) {
    sheetRows.write('<row r="${ri + 1}">');
    for (var ci = 0; ci < rows[ri].length; ci++) {
      final v = rows[ri][ci];
      final ref = '${_col(ci)}${ri + 1}';
      final s = ri == 0 ? ' s="1"' : '';
      if (v is num && v.isFinite) {
        sheetRows.write('<c r="$ref"$s><v>$v</v></c>');
      } else if (v == null || '$v'.isEmpty) {
        sheetRows.write('<c r="$ref"$s/>');
      } else {
        sheetRows.write('<c r="$ref" t="inlineStr"$s><is><t xml:space="preserve">${_esc(v)}</t></is></c>');
      }
    }
    sheetRows.write('</row>');
  }
  const head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  final files = <(String, String)>[
    (
      '[Content_Types].xml',
      '$head<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>',
    ),
    ('_rels/.rels', '$head<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'),
    (
      'xl/workbook.xml',
      '$head<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="${_esc(name)}" sheetId="1" r:id="rId1"/></sheets></workbook>',
    ),
    (
      'xl/_rels/workbook.xml.rels',
      '$head<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
    ),
    (
      'xl/styles.xml',
      '$head<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFF1F2F6"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>',
    ),
    (
      'xl/worksheets/sheet1.xml',
      '$head<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>$cols<sheetData>$sheetRows</sheetData></worksheet>',
    ),
  ];
  return ntZip([for (final (n, t) in files) (n, utf8.encode(t))]);
}

// ---------------------------------------------------------------- PDF from page pictures (A4, 595×842 pt)
const ntA4 = ui.Size(595.28, 841.89);

Future<Uint8List> ntPdf(List<ui.Image> pages, {ui.Size page = ntA4, String title = ''}) async {
  final objects = <List<int>>[]; // object n = objects[n - 1]
  int add(List<int> bytes) {
    objects.add(bytes);
    return objects.length;
  }

  List<int> latin(String s) => latin1.encode(s);
  final catalog = add(const []); // filled at the end
  final pagesRoot = add(const []);
  final kids = <int>[];
  for (final img in pages) {
    final raw = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (raw == null) continue;
    final px = raw.buffer.asUint8List();
    final rgb = Uint8List(img.width * img.height * 3);
    for (var i = 0, j = 0; i < px.length; i += 4, j += 3) {
      // the pages are on white: a see-through pixel becomes white
      final a = px[i + 3];
      if (a == 255) {
        rgb[j] = px[i];
        rgb[j + 1] = px[i + 1];
        rgb[j + 2] = px[i + 2];
      } else {
        final k = 255 - a;
        rgb[j] = (px[i] * a ~/ 255) + k;
        rgb[j + 1] = (px[i + 1] * a ~/ 255) + k;
        rgb[j + 2] = (px[i + 2] * a ~/ 255) + k;
      }
    }
    final data = ZLibEncoder(level: 6).convert(rgb);
    final imgObj = add([
      ...latin('<< /Type /XObject /Subtype /Image /Width ${img.width} /Height ${img.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode /Length ${data.length} >>\nstream\n'),
      ...data,
      ...latin('\nendstream'),
    ]);
    final w = page.width.toStringAsFixed(2), h = page.height.toStringAsFixed(2);
    final content = latin('q $w 0 0 $h 0 0 cm /Im0 Do Q');
    final contentObj = add([...latin('<< /Length ${content.length} >>\nstream\n'), ...content, ...latin('\nendstream')]);
    kids.add(add(latin('<< /Type /Page /Parent $pagesRoot 0 R /MediaBox [0 0 $w $h] /Resources << /XObject << /Im0 $imgObj 0 R >> >> /Contents $contentObj 0 R >>')));
  }
  objects[catalog - 1] = latin('<< /Type /Catalog /Pages $pagesRoot 0 R >>');
  objects[pagesRoot - 1] = latin('<< /Type /Pages /Kids [${kids.map((k) => '$k 0 R').join(' ')}] /Count ${kids.length} >>');
  // the title in the info dictionary (UTF-16, so Khmer titles work too)
  final t = title.isEmpty ? 'Note' : title;
  final utf16 = <int>[0xFE, 0xFF];
  for (final u in t.codeUnits) {
    utf16
      ..add(u >> 8)
      ..add(u & 0xFF);
  }
  final hex = utf16.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final info = add(latin('<< /Title <$hex> /Producer (BizHub) >>'));

  final out = BytesBuilder()..add(latin('%PDF-1.4\n%âãÏÓ\n'));
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out
      ..add(latin('${i + 1} 0 obj\n'))
      ..add(objects[i])
      ..add(latin('\nendobj\n'));
  }
  final xref = out.length;
  out.add(latin('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n'));
  for (final o in offsets) {
    out.add(latin('${o.toString().padLeft(10, '0')} 00000 n \n'));
  }
  out.add(latin('trailer\n<< /Size ${objects.length + 1} /Root $catalog 0 R /Info $info 0 R >>\nstartxref\n$xref\n%%EOF\n'));
  return out.toBytes();
}
