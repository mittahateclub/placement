import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../models/resume_data.dart';

/// Calls Groq (Llama 3.3 70B) with the same prompt the web app uses to
/// tailor a resume against a job description.
class GroqService {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';

  static const int _maxProfileSize = 50000;
  static const int _maxCompanyName = 200;
  static const int _maxJobDesc = 10000;

  static String _sanitize(String input, int maxLength) {
    final cleaned = input
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    return cleaned.length > maxLength
        ? cleaned.substring(0, maxLength)
        : cleaned;
  }

  static Future<ResumeData> generateTailoredResume({
    required Map<String, dynamic> profileData,
    required String companyName,
    required String jobDescription,
  }) async {
    if (!AppConfig.hasGroqKey) {
      throw Exception(
          'No Groq API key configured. Add one from the AI settings.');
    }

    final profileStr = jsonEncode(_jsonSafe(profileData));
    if (profileStr.length > _maxProfileSize) {
      throw Exception('Profile data too large.');
    }
    final cleanCompany = _sanitize(companyName, _maxCompanyName);
    final cleanJobDesc = _sanitize(jobDescription, _maxJobDesc);
    if (cleanCompany.isEmpty) throw Exception('Company name is required.');
    if (cleanJobDesc.isEmpty) throw Exception('Job description is required.');

    final prompt = '''
You are an expert ATS-friendly resume writer. Your task is to tailor the provided user profile data for a specific job application.

Target Company: $cleanCompany
Job Description: $cleanJobDesc

User's Raw Profile Data (all fields stored in their profile):
$profileStr

Instructions:
1. Analyze the job description and extract key skills, tools, and requirements.
2. Use ALL available fields from the profile data — name, phone, email, linkedinUrl, githubUrl, education, experience, technicalSkills, projects, achievements, positions, relevantCoursework, extracurriculars — to build the resume.
3. Rewrite experience, projects, and skills to highlight the most relevant overlaps with the job description. Use impactful, concise bullet points.
4. For Education: format as "Institution | Location | Date\\nDegree/Description" with bullet points for notable info, blank lines between entries.
5. For Experience: format as "Role — Title | Date\\nOrg | Location\\n- bullet\\n- bullet" with blank lines between entries.
6. For Projects: format as "Project Name | Tech Stack | Date\\n- bullet\\n- bullet" with blank lines between entries.
7. For Extracurriculars: format as "Title | Organization | Date" one per line.
8. For Achievements: format as "Award Name – Description | Date" one per line. Include positions of responsibility here too.
9. Use **double asterisks** around important words/phrases for bold emphasis in bullets.
10. Keep tone professional and impactful.
11. IMPORTANT: "Technical Skills" and "Relevant Coursework" are SEPARATE sections. Do NOT repeat coursework items in skills or vice versa. Skills = programming languages, frameworks, tools, technologies. Coursework = academic courses/subjects taken.
12. Output the "coursework" field as a simple comma-separated list of course names. Do NOT duplicate any coursework content in the "skills" field.
13. Extract a "keywords" array: list the top 10–20 important keywords, skills, tools, and phrases from the job description that appear (or were woven into) the resume. These will be highlighted in the preview so the student can see which JD terms their resume covers.

Format the output STRICTLY as a JSON object with NO markdown fences, NO extra text — just raw JSON:

{
  "fullName": "Full name from profile",
  "phone": "Phone number",
  "email": "Email address",
  "website": "Personal website if available, else empty string",
  "github": "GitHub URL from githubUrl field",
  "linkedin": "LinkedIn URL from linkedinUrl field",
  "education": "Formatted education block",
  "experience": "Formatted experience block tailored to the job",
  "skills": "Formatted technical skills — Languages: ...\\nFrameworks: ...\\nTools: ...",
  "projects": "Formatted projects block tailored to the job",
  "coursework": "Relevant coursework as comma-separated list",
  "extracurriculars": "Formatted extracurriculars block",
  "achievements": "Formatted achievements block",
  "keywords": ["keyword1", "keyword2", "..."]
}
''';

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.groqApiKey}',
      },
      body: jsonEncode({
        'model': _model,
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      dynamic msg;
      if (body is Map) {
        msg = (body['error'] as Map?)?['message'];
      }
      throw Exception(msg ?? 'Groq request failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content =
        data['choices']?[0]?['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('No response from AI.');
    }

    final cleaned = content
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();

    final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    return ResumeData.fromAiJson(parsed);
  }

  /// Strips Firestore-specific values (Timestamps etc.) so jsonEncode works.
  static dynamic _jsonSafe(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _jsonSafe(v)));
    }
    if (value is List) return value.map(_jsonSafe).toList();
    if (value is num || value is String || value is bool || value == null) {
      return value;
    }
    return value.toString();
  }
}
