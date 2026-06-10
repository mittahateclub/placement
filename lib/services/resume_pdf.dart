import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/resume_data.dart';

/// Renders a resume as an A4 PDF using the same single-column serif layout
/// as the web app's export page, then opens the system share/print sheet.
class ResumePdf {
  ResumePdf._();

  static final _base = pw.Font.times();
  static final _bold = pw.Font.timesBold();
  static final _italic = pw.Font.timesItalic();
  static final _boldItalic = pw.Font.timesBoldItalic();

  static Future<void> share(ResumeData data) async {
    final bytes = await build(data);
    final name = data.fullName.trim().isEmpty
        ? 'My_Resume'
        : '${data.fullName.trim().replaceAll(RegExp(r'\s+'), '_')}_Resume';
    await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
  }

  static Future<Uint8List> build(ResumeData data) async {
    final doc = pw.Document();

    final contactItems = [
      data.website,
      data.email,
      data.phone,
      data.linkedin.replaceFirst('https://', ''),
      data.github.replaceFirst('https://', ''),
    ].where((s) => s.trim().isNotEmpty).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(
          base: _base,
          bold: _bold,
          italic: _italic,
          boldItalic: _boldItalic,
        ),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              data.fullName.trim().isEmpty ? 'Your Name' : data.fullName,
              style: pw.TextStyle(font: _bold, fontSize: 22),
            ),
          ),
          if (contactItems.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Center(
                child: pw.Text(
                  contactItems.join('  |  '),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9.5),
                ),
              ),
            ),
          ..._section('Education', data.education, _blocksWithHeader2),
          ..._section('Experience', data.experience, _blocksWithHeader2),
          ..._section('Projects', data.projects, _projectBlocks),
          if (data.coursework.trim().isNotEmpty) ...[
            _header('Relevant Coursework'),
            pw.Text(_stripBold(data.coursework),
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
          ],
          if (data.skills.trim().isNotEmpty) ...[
            _header('Technical Skills'),
            ..._skillLines(data.skills),
          ],
          ..._section(
              'Extracurriculars / Activities', data.extracurriculars, _rows),
          ..._section('Achievements & Certifications', data.achievements,
              _achievementRows),
        ],
      ),
    );

    return doc.save();
  }

  static List<pw.Widget> _section(String title, String raw,
      List<pw.Widget> Function(String raw) builder) {
    if (raw.trim().isEmpty) return const [];
    return [_header(title), ...builder(raw)];
  }

  static pw.Widget _header(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
        padding: const pw.EdgeInsets.only(bottom: 2),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 0.8)),
        ),
        width: double.infinity,
        child: pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(font: _bold, fontSize: 10.5, letterSpacing: 1.2),
        ),
      );

  static String _stripBold(String s) => s.replaceAll('**', '');

  /// Turns "text with **bold** parts" into a RichText.
  static pw.Widget _rich(String line,
      {double fontSize = 10, pw.Font? baseFont}) {
    final spans = <pw.InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var index = 0;
    for (final m in pattern.allMatches(line)) {
      if (m.start > index) {
        spans.add(pw.TextSpan(text: line.substring(index, m.start)));
      }
      spans.add(pw.TextSpan(
        text: m.group(1),
        style: pw.TextStyle(font: _bold),
      ));
      index = m.end;
    }
    if (index < line.length) {
      spans.add(pw.TextSpan(text: line.substring(index)));
    }
    return pw.RichText(
      text: pw.TextSpan(
        style: pw.TextStyle(font: baseFont ?? _base, fontSize: fontSize),
        children: spans,
      ),
    );
  }

  static pw.Widget _bullets(List<String> lines) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2, left: 2),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 1.5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('•  ', style: const pw.TextStyle(fontSize: 10)),
                    pw.Expanded(
                      child: _rich(
                          line.replaceFirst(RegExp(r'^[-•]\s*'), '')),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  static pw.Widget _splitRow(String left, String right,
      {bool boldLeft = false, bool italicLeft = false, double size = 10.5}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _rich(
            _stripBoldKeep(left),
            fontSize: size,
            baseFont: boldLeft
                ? _bold
                : italicLeft
                    ? _italic
                    : _base,
          ),
        ),
        if (right.trim().isNotEmpty)
          pw.Text(right, style: pw.TextStyle(font: _base, fontSize: 9.5)),
      ],
    );
  }

  static String _stripBoldKeep(String s) => s; // bold markers handled by _rich

  /// Education & Experience: line1 "left | right", line2 italic "left | right",
  /// remaining lines are bullets. Blocks separated by blank lines.
  static List<pw.Widget> _blocksWithHeader2(String raw) {
    final widgets = <pw.Widget>[];
    for (final block in raw.split(RegExp(r'\n\n+'))) {
      final lines =
          block.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;
      final parts1 = lines[0].split('|').map((p) => p.trim()).toList();
      final parts2 = lines.length > 1
          ? lines[1].split('|').map((p) => p.trim()).toList()
          : <String>[];
      final bullets = lines.length > 2 ? lines.sublist(2) : <String>[];

      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _splitRow(parts1.isNotEmpty ? parts1[0] : '',
                parts1.length > 1 ? parts1[1] : '',
                boldLeft: true),
            if (parts2.isNotEmpty)
              _splitRow(parts2[0], parts2.length > 1 ? parts2[1] : '',
                  italicLeft: true, size: 9.5),
            if (bullets.isNotEmpty) _bullets(bullets),
          ],
        ),
      ));
    }
    return widgets;
  }

  /// Projects: line1 "Name | Tech | Date", remaining lines are bullets.
  static List<pw.Widget> _projectBlocks(String raw) {
    final widgets = <pw.Widget>[];
    for (final block in raw.split(RegExp(r'\n\n+'))) {
      final lines =
          block.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;
      final parts = lines[0].split('|').map((p) => p.trim()).toList();
      final bullets = lines.length > 1 ? lines.sublist(1) : <String>[];

      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.RichText(
                    text: pw.TextSpan(children: [
                      pw.TextSpan(
                        text: _stripBold(parts.isNotEmpty ? parts[0] : ''),
                        style: pw.TextStyle(font: _bold, fontSize: 10.5),
                      ),
                      if (parts.length > 1 && parts[1].isNotEmpty)
                        pw.TextSpan(
                          text: '  |  ${_stripBold(parts[1])}',
                          style: pw.TextStyle(font: _italic, fontSize: 9.5),
                        ),
                    ]),
                  ),
                ),
                if (parts.length > 2 && parts[2].isNotEmpty)
                  pw.Text(parts[2],
                      style: pw.TextStyle(font: _base, fontSize: 9.5)),
              ],
            ),
            if (bullets.isNotEmpty) _bullets(bullets),
          ],
        ),
      ));
    }
    return widgets;
  }

  /// Extracurriculars: one entry per line "Activity | Role | Date".
  static List<pw.Widget> _rows(String raw) {
    final widgets = <pw.Widget>[];
    for (final line in raw.split('\n').where((l) => l.trim().isNotEmpty)) {
      final parts = line.split('|').map((p) => p.trim()).toList();
      final left = [
        if (parts.isNotEmpty) parts[0],
        if (parts.length > 1 && parts[1].isNotEmpty) parts[1],
      ].join(' | ');
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2.5),
        child: _splitRow(left, parts.length > 2 ? parts[2] : '',
            boldLeft: true, size: 10),
      ));
    }
    return widgets;
  }

  /// Achievements: "Title – Description | Date" with underlined titles.
  static List<pw.Widget> _achievementRows(String raw) {
    final widgets = <pw.Widget>[];
    for (final line in raw.split('\n').where((l) => l.trim().isNotEmpty)) {
      final pipeIdx = line.lastIndexOf('|');
      final desc = (pipeIdx > -1 ? line.substring(0, pipeIdx) : line).trim();
      final date = pipeIdx > -1 ? line.substring(pipeIdx + 1).trim() : '';
      final dashIdx = desc.indexOf('–');
      final title =
          (dashIdx > -1 ? desc.substring(0, dashIdx) : desc).trim();
      final sub = dashIdx > -1 ? desc.substring(dashIdx + 1).trim() : '';

      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(
                    text: _stripBold(title),
                    style: pw.TextStyle(
                      font: _bold,
                      fontSize: 10,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    pw.TextSpan(
                      text: ' – ${_stripBold(sub)}',
                      style: pw.TextStyle(font: _base, fontSize: 10),
                    ),
                ]),
              ),
            ),
            if (date.isNotEmpty)
              pw.Text(date, style: pw.TextStyle(font: _base, fontSize: 9.5)),
          ],
        ),
      ));
    }
    return widgets;
  }

  /// Skills: each line may contain "**Category:** items".
  static List<pw.Widget> _skillLines(String raw) => [
        for (final line in raw.split('\n').where((l) => l.trim().isNotEmpty))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: _rich(line),
          ),
      ];
}
