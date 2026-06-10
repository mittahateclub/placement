import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/resume_data.dart';

/// Mobile rendering of the A4 resume layout used on the website — white
/// paper, serif type, small-caps section rules, keyword highlighting.
class ResumePreview extends StatelessWidget {
  final ResumeData data;
  final List<String> keywords;

  const ResumePreview({super.key, required this.data, this.keywords = const []});

  static const _ink = Color(0xFF111111);

  TextStyle _serif({
    double size = 11,
    FontWeight weight = FontWeight.w400,
    FontStyle style = FontStyle.normal,
    TextDecoration? decoration,
  }) =>
      GoogleFonts.sourceSerif4(
        fontSize: size,
        fontWeight: weight,
        fontStyle: style,
        color: _ink,
        height: 1.4,
        decoration: decoration,
      );

  bool _has(String v) => v.trim().isNotEmpty;

  /// Splits "text **bold** more" into styled spans, highlighting keywords.
  List<InlineSpan> _spans(String text,
      {double size = 11,
      FontWeight weight = FontWeight.w400,
      FontStyle style = FontStyle.normal}) {
    final spans = <InlineSpan>[];
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    var index = 0;

    void addText(String chunk, FontWeight w) {
      if (chunk.isEmpty) return;
      if (keywords.isEmpty) {
        spans.add(TextSpan(
            text: chunk,
            style: _serif(size: size, weight: w, style: style)));
        return;
      }
      // Keyword highlighting
      final escaped = keywords
          .where((k) => k.trim().isNotEmpty)
          .map(RegExp.escape)
          .join('|');
      if (escaped.isEmpty) {
        spans.add(TextSpan(
            text: chunk,
            style: _serif(size: size, weight: w, style: style)));
        return;
      }
      final kwPattern = RegExp('($escaped)', caseSensitive: false);
      var pos = 0;
      for (final m in kwPattern.allMatches(chunk)) {
        if (m.start > pos) {
          spans.add(TextSpan(
              text: chunk.substring(pos, m.start),
              style: _serif(size: size, weight: w, style: style)));
        }
        spans.add(TextSpan(
          text: m.group(0),
          style: _serif(size: size, weight: w, style: style).copyWith(
            backgroundColor: const Color(0xFFFDF3A8),
          ),
        ));
        pos = m.end;
      }
      if (pos < chunk.length) {
        spans.add(TextSpan(
            text: chunk.substring(pos),
            style: _serif(size: size, weight: w, style: style)));
      }
    }

    for (final m in boldPattern.allMatches(text)) {
      if (m.start > index) addText(text.substring(index, m.start), weight);
      addText(m.group(1)!, FontWeight.w700);
      index = m.end;
    }
    if (index < text.length) addText(text.substring(index), weight);
    return spans;
  }

  Widget _rich(String text,
          {double size = 11,
          FontWeight weight = FontWeight.w400,
          FontStyle style = FontStyle.normal}) =>
      Text.rich(TextSpan(
          children: _spans(text, size: size, weight: weight, style: style)));

  Widget _splitRow(String left, String right,
      {FontWeight weight = FontWeight.w400,
      FontStyle style = FontStyle.normal,
      double size = 11}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _rich(left, size: size, weight: weight, style: style)),
        if (right.trim().isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(right, style: _serif(size: 10)),
        ],
      ],
    );
  }

  Widget _bullets(List<String> lines) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 1.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ', style: _serif(size: 10.5)),
                        Expanded(
                          child: _rich(
                              line.replaceFirst(RegExp(r'^[-•]\s*'), ''),
                              size: 10.5),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      );

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: _serif(size: 10.5, weight: FontWeight.w700)
                    .copyWith(letterSpacing: 1.4)),
            const SizedBox(height: 2),
            Container(height: 0.8, color: _ink),
          ],
        ),
      );

  List<Widget> _headerBlocks(String raw) {
    // Education/Experience: 2 header lines + bullets per block.
    final widgets = <Widget>[];
    for (final block in raw.split(RegExp(r'\n\n+'))) {
      final lines =
          block.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;
      final p1 = lines[0].split('|').map((p) => p.trim()).toList();
      final p2 = lines.length > 1
          ? lines[1].split('|').map((p) => p.trim()).toList()
          : <String>[];
      final bullets = lines.length > 2 ? lines.sublist(2) : <String>[];
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _splitRow(p1.isNotEmpty ? p1[0] : '', p1.length > 1 ? p1[1] : '',
                weight: FontWeight.w700, size: 11.5),
            if (p2.isNotEmpty)
              _splitRow(p2[0], p2.length > 1 ? p2[1] : '',
                  style: FontStyle.italic, size: 10.5),
            if (bullets.isNotEmpty) _bullets(bullets),
          ],
        ),
      ));
    }
    return widgets;
  }

  List<Widget> _projectBlocks(String raw) {
    final widgets = <Widget>[];
    for (final block in raw.split(RegExp(r'\n\n+'))) {
      final lines =
          block.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;
      final parts = lines[0].split('|').map((p) => p.trim()).toList();
      final bullets = lines.length > 1 ? lines.sublist(1) : <String>[];
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    ..._spans(parts.isNotEmpty ? parts[0] : '',
                        size: 11.5, weight: FontWeight.w700),
                    if (parts.length > 1 && parts[1].isNotEmpty)
                      ..._spans(' | ${parts[1]}',
                          size: 10.5, style: FontStyle.italic),
                  ])),
                ),
                if (parts.length > 2 && parts[2].isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(parts[2], style: _serif(size: 10)),
                ],
              ],
            ),
            if (bullets.isNotEmpty) _bullets(bullets),
          ],
        ),
      ));
    }
    return widgets;
  }

  List<Widget> _lineRows(String raw) => raw
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .map((line) {
        final parts = line.split('|').map((p) => p.trim()).toList();
        final left = [
          if (parts.isNotEmpty) parts[0],
          if (parts.length > 1 && parts[1].isNotEmpty) parts[1],
        ].join(' | ');
        return Padding(
          padding: const EdgeInsets.only(bottom: 2.5),
          child: _splitRow(left, parts.length > 2 ? parts[2] : '',
              weight: FontWeight.w700, size: 10.5),
        );
      })
      .toList();

  List<Widget> _achievementRows(String raw) => raw
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .map((line) {
        final pipeIdx = line.lastIndexOf('|');
        final desc =
            (pipeIdx > -1 ? line.substring(0, pipeIdx) : line).trim();
        final date = pipeIdx > -1 ? line.substring(pipeIdx + 1).trim() : '';
        final dashIdx = desc.indexOf('–');
        final title =
            (dashIdx > -1 ? desc.substring(0, dashIdx) : desc).trim();
        final sub = dashIdx > -1 ? desc.substring(dashIdx + 1).trim() : '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                    text: title.replaceAll('**', ''),
                    style: _serif(
                        size: 10.5,
                        weight: FontWeight.w700,
                        decoration: TextDecoration.underline),
                  ),
                  if (sub.isNotEmpty)
                    ..._spans(' – $sub', size: 10.5),
                ])),
              ),
              if (date.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(date, style: _serif(size: 10)),
              ],
            ],
          ),
        );
      })
      .toList();

  @override
  Widget build(BuildContext context) {
    final contactItems = [
      data.website,
      data.email,
      data.phone,
      data.linkedin.replaceFirst('https://', ''),
      data.github.replaceFirst('https://', ''),
    ].where((s) => s.trim().isNotEmpty).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              _has(data.fullName) ? data.fullName : 'Your Name',
              textAlign: TextAlign.center,
              style: _serif(size: 22, weight: FontWeight.w800),
            ),
          ),
          if (contactItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Center(
                child: Text(
                  contactItems.join('  |  '),
                  textAlign: TextAlign.center,
                  style: _serif(size: 9.5),
                ),
              ),
            ),
          if (_has(data.education)) ...[
            _sectionHeader('Education'),
            ..._headerBlocks(data.education),
          ],
          if (_has(data.experience)) ...[
            _sectionHeader('Experience'),
            ..._headerBlocks(data.experience),
          ],
          if (_has(data.projects)) ...[
            _sectionHeader('Projects'),
            ..._projectBlocks(data.projects),
          ],
          if (_has(data.coursework)) ...[
            _sectionHeader('Relevant Coursework'),
            _rich(data.coursework, size: 10.5),
          ],
          if (_has(data.skills)) ...[
            _sectionHeader('Technical Skills'),
            ...data.skills
                .split('\n')
                .where((l) => l.trim().isNotEmpty)
                .map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _rich(l, size: 10.5),
                    )),
          ],
          if (_has(data.extracurriculars)) ...[
            _sectionHeader('Extracurriculars / Activities'),
            ..._lineRows(data.extracurriculars),
          ],
          if (_has(data.achievements)) ...[
            _sectionHeader('Achievements & Certifications'),
            ..._achievementRows(data.achievements),
          ],
        ],
      ),
    );
  }
}
