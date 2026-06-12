import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';

/// Result of scraping an event/job posting link.
class ScrapedEvent {
  final String? title;
  final String? description;
  final String? company;
  final String? location;
  final String? type; // one of AppColors.eventTypeColors keys
  final String? imageUrl; // og:image if the page exposes one
  final DateTime? deadline;

  const ScrapedEvent({
    this.title,
    this.description,
    this.company,
    this.location,
    this.type,
    this.imageUrl,
    this.deadline,
  });
}

/// Fetches an event/job link, pulls the page's social image (og:image) and
/// visible text, then asks Groq to structure it into event fields.
class EventScraper {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';
  static const _maxPageText = 9000;

  static Future<ScrapedEvent> scrape(String rawUrl) async {
    var url = rawUrl.trim();
    if (url.isEmpty) throw Exception('Enter a link first.');
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) throw Exception('Invalid link.');

    // 1. Fetch the page. Many job boards block default clients, so send a
    // browser-like User-Agent.
    http.Response page;
    try {
      page = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml',
      }).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw Exception('Could not reach the link.');
    }
    if (page.statusCode != 200) {
      throw Exception('Page returned ${page.statusCode}.');
    }
    final html = utf8.decode(page.bodyBytes, allowMalformed: true);

    final imageUrl = _extractImage(html, uri);
    final pageText = _visibleText(html);
    if (pageText.length < 80) {
      // Nothing meaningful to summarize — still return the image if found.
      if (imageUrl != null) return ScrapedEvent(imageUrl: imageUrl);
      throw Exception('The page has no readable content.');
    }

    // 2. Ask Groq to structure it.
    if (!AppConfig.hasGroqKey) {
      throw Exception(
          'No Groq API key — start the app with --dart-define-from-file=env.json');
    }
    final prompt = '''
You are helping a university placement admin create an event post from a web page.
Below is the visible text scraped from $url

PAGE TEXT:
$pageText

Extract the posting into STRICT JSON (no markdown fences, no extra text):
{
  "title": "short event/job title, max 80 chars",
  "company": "organizing company or institution, or null",
  "location": "city / venue / Remote, or null",
  "eventType": "one of: event, internship, hackathon, research, workshop",
  "description": "clean 80-140 word description written like a social post caption: what it is, who should apply, key requirements/skills, perks. Plain text, no hashtags.",
  "deadline": "application deadline or event date as YYYY-MM-DD, or null"
}
Use null for anything not present in the text. Do not invent details.''';

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.groqApiKey}',
            },
            body: jsonEncode({
              'model': _model,
              'temperature': 0.2,
              'response_format': {'type': 'json_object'},
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw Exception('AI request timed out — try again.');
    }
    if (response.statusCode != 200) {
      throw Exception('AI extraction failed (${response.statusCode}).');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = body['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('No response from AI.');
    }
    final parsed = jsonDecode(content
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim()) as Map<String, dynamic>;

    String? str(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty || s == 'null') ? null : s;
    }

    const types = ['event', 'internship', 'hackathon', 'research', 'workshop'];
    final type = str(parsed['eventType'])?.toLowerCase();

    return ScrapedEvent(
      title: str(parsed['title']),
      description: str(parsed['description']),
      company: str(parsed['company']),
      location: str(parsed['location']),
      type: types.contains(type) ? type : null,
      imageUrl: imageUrl,
      deadline: str(parsed['deadline']) != null
          ? DateTime.tryParse(str(parsed['deadline'])!)
          : null,
    );
  }

  /// og:image / twitter:image, resolved to an absolute URL.
  static String? _extractImage(String html, Uri pageUri) {
    for (final pattern in [
      r'''<meta[^>]+property=["']og:image["'][^>]*content=["']([^"']+)["']''',
      r'''<meta[^>]+content=["']([^"']+)["'][^>]*property=["']og:image["']''',
      r'''<meta[^>]+name=["']twitter:image["'][^>]*content=["']([^"']+)["']''',
      r'''<meta[^>]+content=["']([^"']+)["'][^>]*name=["']twitter:image["']''',
    ]) {
      final m = RegExp(pattern, caseSensitive: false).firstMatch(html);
      final raw = m?.group(1)?.trim();
      if (raw == null || raw.isEmpty) continue;
      final resolved = pageUri.resolve(raw).toString();
      if (resolved.startsWith('http')) return resolved;
    }
    return null;
  }

  /// Strips scripts/styles/tags and collapses whitespace.
  static String _visibleText(String html) {
    var text = html
        .replaceAll(
            RegExp(r'<(script|style|noscript|svg|head)[\s\S]*?</\1>',
                caseSensitive: false),
            ' ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|li|h[1-6]|tr)>', caseSensitive: false),
            '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    const entities = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&nbsp;': ' ',
      '&mdash;': '—',
      '&ndash;': '–',
    };
    entities.forEach((k, v) => text = text.replaceAll(k, v));
    text = text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\s*\n\s*'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return text.length > _maxPageText ? text.substring(0, _maxPageText) : text;
  }
}
