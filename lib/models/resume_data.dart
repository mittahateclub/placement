import 'package:cloud_firestore/cloud_firestore.dart';

/// One resume document in the shared `resumes` collection — the field
/// names match the web app exactly so both clients stay compatible.
class ResumeData {
  String? id;
  String fullName;
  String phone;
  String email;
  String website;
  String github;
  String linkedin;
  String education;
  String experience;
  String skills;
  String projects;
  String coursework;
  String extracurriculars;
  String achievements;
  String targetCompany;
  List<String> keywords;
  String? uploadedFileUrl;
  String? uploadedFileName;
  String? uploadedFileType;
  DateTime? updatedAt;

  ResumeData({
    this.id,
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.github = '',
    this.linkedin = '',
    this.education = '',
    this.experience = '',
    this.skills = '',
    this.projects = '',
    this.coursework = '',
    this.extracurriculars = '',
    this.achievements = '',
    this.targetCompany = '',
    this.keywords = const [],
    this.uploadedFileUrl,
    this.uploadedFileName,
    this.uploadedFileType,
    this.updatedAt,
  });

  bool get isUploadedFileOnly =>
      (uploadedFileUrl ?? '').isNotEmpty && fullName.trim().isEmpty;

  static String _s(dynamic v) => (v as String?) ?? '';

  factory ResumeData.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ResumeData(
      id: doc.id,
      fullName: _s(d['fullName']),
      phone: _s(d['phone']),
      email: _s(d['email']),
      website: _s(d['website']),
      github: _s(d['github']),
      linkedin: _s(d['linkedin']),
      education: _s(d['education']),
      experience: _s(d['experience']),
      skills: _s(d['skills']),
      projects: _s(d['projects']),
      coursework: _s(d['coursework']),
      extracurriculars: _s(d['extracurriculars']),
      achievements: _s(d['achievements']),
      targetCompany: _s(d['targetCompany']),
      keywords: List<String>.from(
          (d['keywords'] as List?)?.map((e) => e.toString()) ?? const []),
      uploadedFileUrl: d['uploadedFileUrl'] as String?,
      uploadedFileName: d['uploadedFileName'] as String?,
      uploadedFileType: d['uploadedFileType'] as String?,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ResumeData.fromAiJson(Map<String, dynamic> json) {
    return ResumeData(
      fullName: _s(json['fullName']),
      phone: _s(json['phone']),
      email: _s(json['email']),
      website: _s(json['website']),
      github: _s(json['github']),
      linkedin: _s(json['linkedin']),
      education: _s(json['education']),
      experience: _s(json['experience']),
      skills: _s(json['skills']),
      projects: _s(json['projects']),
      coursework: _s(json['coursework']),
      extracurriculars: _s(json['extracurriculars']),
      achievements: _s(json['achievements']),
      keywords: List<String>.from(
          (json['keywords'] as List?)?.map((e) => e.toString()) ?? const []),
    );
  }

  /// Builds the initial resume from the student's `users/{uid}` profile,
  /// mirroring mapProfileToResumeData on the web.
  factory ResumeData.fromProfile(Map<String, dynamic> p) {
    String fmtEntries(List? entries, String Function(Map e) fmt) =>
        (entries ?? const [])
            .whereType<Map>()
            .map(fmt)
            .where((s) => s.trim().isNotEmpty)
            .join('\n\n');

    String s(dynamic v) => (v as String?) ?? '';

    String dateRange(Map e) {
      final from = s(e['fromDate']);
      final to = s(e['toDate']);
      if (from.isNotEmpty && to.isNotEmpty) return '$from – $to';
      if (from.isNotEmpty) return '$from – Present';
      return to;
    }

    final eduEntries = p['educationEntries'] as List?;
    final expEntries = p['experienceEntries'] as List?;
    final projEntries = p['projectEntries'] as List?;
    final achEntries = p['achievementEntries'] as List?;
    final extraEntries = p['extracurricularEntries'] as List?;

    String bullets(String description) => description
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) => '- ${l.replaceFirst(RegExp(r'^[-•]\s*'), '')}')
        .join('\n');

    return ResumeData(
      fullName: s(p['name']),
      phone: s(p['phone']),
      email: s(p['email']),
      website: s(p['website']),
      github: s(p['githubUrl']),
      linkedin: s(p['linkedinUrl']),
      education: (eduEntries?.isNotEmpty ?? false)
          ? fmtEntries(eduEntries, (e) {
              final degree = s(e['degree']);
              final cgpa = s(e['cgpa']);
              return '${s(e['institution'])} | ${s(e['location'])} | ${dateRange(e)}\n'
                  '$degree${cgpa.isNotEmpty ? ' – GPA: $cgpa' : ''}';
            })
          : s(p['education']),
      experience: (expEntries?.isNotEmpty ?? false)
          ? fmtEntries(expEntries, (e) {
              return '${s(e['role'])} | ${dateRange(e)}\n'
                  '${s(e['company'])} | ${s(e['location'])}\n'
                  '${bullets(s(e['description']))}';
            })
          : s(p['experience']),
      skills: s(p['technicalSkills']),
      projects: (projEntries?.isNotEmpty ?? false)
          ? fmtEntries(projEntries, (e) {
              return '${s(e['title'])} | ${s(e['techStack'])} | ${dateRange(e)}\n'
                  '${bullets(s(e['description']))}';
            })
          : s(p['projects']),
      coursework: s(p['relevantCoursework']),
      extracurriculars: (extraEntries?.isNotEmpty ?? false)
          ? (extraEntries ?? const [])
              .whereType<Map>()
              .map((e) =>
                  '${s(e['activity'])} | ${s(e['role'])} | ${dateRange(e)}')
              .join('\n')
          : s(p['extracurriculars']),
      achievements: (achEntries?.isNotEmpty ?? false)
          ? (achEntries ?? const [])
              .whereType<Map>()
              .map((e) =>
                  '${s(e['title'])} – ${s(e['issuer'])} | ${s(e['fromDate'])}')
              .join('\n')
          : s(p['achievements']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'website': website,
        'github': github,
        'linkedin': linkedin,
        'education': education,
        'experience': experience,
        'skills': skills,
        'projects': projects,
        'coursework': coursework,
        'extracurriculars': extracurriculars,
        'achievements': achievements,
        'targetCompany':
            targetCompany.isEmpty ? 'General Resume' : targetCompany,
        'keywords': keywords,
        if (uploadedFileUrl != null) 'uploadedFileUrl': uploadedFileUrl,
        if (uploadedFileName != null) 'uploadedFileName': uploadedFileName,
        if (uploadedFileType != null) 'uploadedFileType': uploadedFileType,
      };

  ResumeData copy() => ResumeData(
        id: id,
        fullName: fullName,
        phone: phone,
        email: email,
        website: website,
        github: github,
        linkedin: linkedin,
        education: education,
        experience: experience,
        skills: skills,
        projects: projects,
        coursework: coursework,
        extracurriculars: extracurriculars,
        achievements: achievements,
        targetCompany: targetCompany,
        keywords: List.of(keywords),
        uploadedFileUrl: uploadedFileUrl,
        uploadedFileName: uploadedFileName,
        uploadedFileType: uploadedFileType,
        updatedAt: updatedAt,
      );

  /// Merge AI output into this resume, keeping previous values when the AI
  /// returned an empty field (same behaviour as the web builder).
  void mergeGenerated(ResumeData g) {
    String pick(String fresh, String old) => fresh.isNotEmpty ? fresh : old;
    fullName = pick(g.fullName, fullName);
    phone = pick(g.phone, phone);
    email = pick(g.email, email);
    website = pick(g.website, website);
    github = pick(g.github, github);
    linkedin = pick(g.linkedin, linkedin);
    education = pick(g.education, education);
    experience = pick(g.experience, experience);
    skills = pick(g.skills, skills);
    projects = pick(g.projects, projects);
    coursework = pick(g.coursework, coursework);
    extracurriculars = pick(g.extracurriculars, extracurriculars);
    achievements = pick(g.achievements, achievements);
    if (g.keywords.isNotEmpty) keywords = g.keywords;
  }
}
