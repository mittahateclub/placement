import 'package:flutter_test/flutter_test.dart';

import 'package:uniship_app/models/resume_data.dart';
import 'package:uniship_app/services/ats_scorer.dart';

void main() {
  test('ATS scorer rewards complete resumes', () {
    final empty = AtsScorer.score(ResumeData(), []);
    final filled = AtsScorer.score(
      ResumeData(
        fullName: 'Test Student',
        email: 'test@uni.edu',
        phone: '1234567890',
        linkedin: 'https://linkedin.com/in/test',
        github: 'https://github.com/test',
        education: 'Uni | City | 2022 - 2026\nB.Tech CSE GPA: 9.0',
        experience: 'SDE Intern | Jun 2025\nAcme | Remote\n'
            '- built APIs serving 100+ users\n- improved latency by 40%\n'
            '- deployed CI pipelines\n- led a team of 3 members\n'
            '- reduced costs by 20%\n- automated reporting',
        projects: 'App | Flutter | 2025\n- developed cross-platform app\n'
            '- launched to 500+ users\n- integrated Firebase auth\n'
            '- optimized startup by 2x',
        skills: 'Languages: Dart, Python\nFrameworks: Flutter\nTools: Git',
        coursework: 'DSA, OS, DBMS',
        achievements: 'Hackathon Winner | 2025',
        extracurriculars: 'Coding Club | Lead | 2024',
      ),
      [],
    );
    expect(filled.total, greaterThan(empty.total));
    expect(filled.total, lessThanOrEqualTo(100));
  });

  test('keyword matching affects ATS keyword score', () {
    final resume = ResumeData(skills: 'Flutter, Firebase, Dart');
    final matchedAll = AtsScorer.score(resume, ['Flutter', 'Dart']);
    final matchedNone = AtsScorer.score(resume, ['Kubernetes', 'Rust']);
    expect(matchedAll.keywords.score, greaterThan(matchedNone.keywords.score));
    expect(matchedAll.keywords.matched, containsAll(['Flutter', 'Dart']));
  });
}
