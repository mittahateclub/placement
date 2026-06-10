import '../models/resume_data.dart';

/// Direct port of the web app's ATS scoring (ats-score.tsx).
class AtsBreakdown {
  final int total;
  final AtsCategory contact;
  final AtsCategory sections;
  final AtsKeywords keywords;
  final AtsCategory depth;
  final AtsCategory quality;

  AtsBreakdown({
    required this.total,
    required this.contact,
    required this.sections,
    required this.keywords,
    required this.depth,
    required this.quality,
  });

  String get gradeLabel => total >= 85
      ? 'Excellent'
      : total >= 70
          ? 'Good'
          : total >= 50
              ? 'Needs Work'
              : 'Poor';
}

class AtsCategory {
  final int score;
  final int max;
  final List<String> details;
  AtsCategory(this.score, this.max, this.details);
}

class AtsKeywords {
  final int score;
  final int max;
  final List<String> matched;
  final List<String> missing;
  AtsKeywords(this.score, this.max, this.matched, this.missing);
}

class AtsScorer {
  AtsScorer._();

  static const _actionVerbs = [
    'achieved', 'built', 'created', 'designed', 'developed', 'engineered',
    'established', 'implemented', 'improved', 'increased', 'integrated',
    'launched', 'led', 'managed', 'optimized', 'orchestrated', 'reduced',
    'resolved', 'spearheaded', 'streamlined', 'transformed', 'architected',
    'automated', 'collaborated', 'configured', 'delivered', 'deployed',
    'maintained', 'mentored', 'migrated', 'monitored', 'published',
    'refactored', 'scaled', 'secured', 'utilized', 'analyzed', 'coordinated',
  ];

  static final _measurablePatterns = [
    RegExp(r'\d+%'),
    RegExp(r'\d+x'),
    RegExp(r'\$\d'),
    RegExp(r'\d+\+?\s*(users?|clients?|customers?|projects?|teams?|members?)',
        caseSensitive: false),
    RegExp(r'reduced\s+.*\s+by\s+\d', caseSensitive: false),
    RegExp(r'increased\s+.*\s+by\s+\d', caseSensitive: false),
    RegExp(r'improved\s+.*\s+by\s+\d', caseSensitive: false),
    RegExp(r'saved\s+.*\s+\d', caseSensitive: false),
  ];

  static bool _has(String v) => v.trim().isNotEmpty;

  static int _countBullets(String text) {
    if (!_has(text)) return 0;
    return text
        .split('\n')
        .where((l) =>
            RegExp(r'^\s*[-•]').hasMatch(l) || l.trim().length > 20)
        .length;
  }

  static AtsBreakdown score(ResumeData data, List<String> keywords) {
    final allText = [
      data.education,
      data.experience,
      data.skills,
      data.projects,
      data.coursework,
      data.extracurriculars,
      data.achievements,
    ].join(' ').toLowerCase();

    // 1. Contact info (15 pts)
    final contactChecks = [
      (data.fullName, 'Full name', 3),
      (data.email, 'Email', 3),
      (data.phone, 'Phone', 3),
      (data.linkedin, 'LinkedIn URL', 3),
      (data.github.isNotEmpty ? data.github : data.website, 'GitHub/Website', 3),
    ];
    var contactScore = 0;
    final contactDetails = <String>[];
    for (final (field, label, pts) in contactChecks) {
      if (_has(field)) {
        contactScore += pts;
        contactDetails.add('✓ $label');
      } else {
        contactDetails.add('✗ $label missing');
      }
    }

    // 2. Section coverage (25 pts)
    final sectionChecks = [
      (data.education, 'Education', 5),
      (data.experience, 'Experience', 5),
      (data.projects, 'Projects', 4),
      (data.skills, 'Technical Skills', 5),
      (data.coursework, 'Coursework', 2),
      (data.achievements, 'Achievements', 2),
      (data.extracurriculars, 'Extracurriculars', 2),
    ];
    var sectionScore = 0;
    final sectionDetails = <String>[];
    for (final (field, label, pts) in sectionChecks) {
      if (_has(field)) {
        sectionScore += pts;
        sectionDetails.add('✓ $label');
      } else {
        sectionDetails.add('✗ $label empty');
      }
    }

    // 3. Keyword match (25 pts)
    var keywordScore = 0;
    final matched = <String>[];
    final missing = <String>[];
    if (keywords.isNotEmpty) {
      for (final kw in keywords) {
        if (allText.contains(kw.toLowerCase())) {
          matched.add(kw);
        } else {
          missing.add(kw);
        }
      }
      keywordScore = (matched.length / keywords.length * 25).round();
    } else {
      keywordScore = 10;
    }

    // 4. Content depth (20 pts)
    var depthScore = 0;
    final depthDetails = <String>[];

    final expBullets = _countBullets(data.experience);
    final projBullets = _countBullets(data.projects);

    if (expBullets >= 6) {
      depthScore += 7;
      depthDetails.add('✓ Experience depth good ($expBullets bullets)');
    } else if (expBullets >= 3) {
      depthScore += 4;
      depthDetails.add('△ Experience could use more detail ($expBullets bullets)');
    } else if (expBullets > 0) {
      depthScore += 2;
      depthDetails.add('✗ Experience too thin ($expBullets bullets)');
    } else {
      depthDetails.add('✗ No experience bullets');
    }

    if (projBullets >= 4) {
      depthScore += 5;
      depthDetails.add('✓ Projects well described ($projBullets bullets)');
    } else if (projBullets >= 2) {
      depthScore += 3;
      depthDetails.add('△ Projects could use more detail ($projBullets bullets)');
    } else if (projBullets > 0) {
      depthScore += 1;
      depthDetails.add('✗ Projects too brief ($projBullets bullets)');
    } else {
      depthDetails.add('✗ No project bullets');
    }

    final skillLines =
        data.skills.split('\n').where((l) => l.trim().isNotEmpty).length;
    if (skillLines >= 3) {
      depthScore += 5;
      depthDetails.add('✓ Skills well categorized ($skillLines lines)');
    } else if (skillLines >= 1) {
      depthScore += 3;
      depthDetails.add('△ Skills could be more detailed ($skillLines lines)');
    } else {
      depthDetails.add('✗ No skills listed');
    }

    final eduBlocks = data.education
        .split(RegExp(r'\n\n+'))
        .where((b) => b.trim().isNotEmpty)
        .length;
    if (eduBlocks >= 1) {
      depthScore += 3;
      depthDetails.add('✓ Education present ($eduBlocks entries)');
    } else {
      depthDetails.add('✗ No education entries');
    }

    // 5. Quality signals (15 pts)
    var qualityScore = 0;
    final qualityDetails = <String>[];

    final expText = '${data.experience} ${data.projects}'.toLowerCase();
    final usedVerbs = _actionVerbs.where(expText.contains).length;
    if (usedVerbs >= 8) {
      qualityScore += 5;
      qualityDetails.add('✓ Strong action verbs ($usedVerbs found)');
    } else if (usedVerbs >= 4) {
      qualityScore += 3;
      qualityDetails.add('△ Some action verbs ($usedVerbs found, aim for 8+)');
    } else {
      qualityScore += 1;
      qualityDetails.add('✗ Few action verbs ($usedVerbs found)');
    }

    final bulletLines = '${data.experience}\n${data.projects}'
        .split('\n')
        .where((l) => l.trim().isNotEmpty);
    final measurableCount = bulletLines
        .where((l) => _measurablePatterns.any((p) => p.hasMatch(l)))
        .length;
    if (measurableCount >= 5) {
      qualityScore += 5;
      qualityDetails.add('✓ Good quantified impact ($measurableCount metrics)');
    } else if (measurableCount >= 2) {
      qualityScore += 3;
      qualityDetails
          .add('△ Some quantified impact ($measurableCount metrics, aim for 5+)');
    } else {
      qualityScore += 1;
      qualityDetails.add('✗ Lacks quantified impact ($measurableCount found)');
    }

    final totalWords =
        allText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (totalWords >= 250 && totalWords <= 800) {
      qualityScore += 5;
      qualityDetails.add('✓ Good length (~$totalWords words)');
    } else if (totalWords > 800) {
      qualityScore += 3;
      qualityDetails.add('△ Resume may be too long (~$totalWords words)');
    } else if (totalWords >= 150) {
      qualityScore += 3;
      qualityDetails.add('△ Resume could be more detailed (~$totalWords words)');
    } else {
      qualityScore += 1;
      qualityDetails.add('✗ Resume too short (~$totalWords words)');
    }

    final total =
        contactScore + sectionScore + keywordScore + depthScore + qualityScore;

    return AtsBreakdown(
      total: total,
      contact: AtsCategory(contactScore, 15, contactDetails),
      sections: AtsCategory(sectionScore, 25, sectionDetails),
      keywords: AtsKeywords(keywordScore, 25, matched, missing),
      depth: AtsCategory(depthScore, 20, depthDetails),
      quality: AtsCategory(qualityScore, 15, qualityDetails),
    );
  }
}
