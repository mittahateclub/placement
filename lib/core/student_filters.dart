/// Branch + GPA targeting shared by event creation (admin) and the
/// student-facing feeds. Events store `targetBranches` (['all'] or a list
/// from [kBranches]) and `minGpa` (null = everyone).
library;

const List<String> kBranches = [
  'CSE',
  'IT',
  'ECE',
  'EEE',
  'Mechanical',
  'Civil',
  'Chemical',
  'Aerospace',
  'Biotech',
  'AI & ML',
  'Data Science',
  'Other',
];

const List<double> kGpaCutoffs = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0];

/// First parseable CGPA from a user profile's education entries.
double? cgpaFromProfile(Map<String, dynamic> data) {
  for (final entry in (data['educationEntries'] as List? ?? [])) {
    if (entry is Map && entry['cgpa'] != null) {
      final v = double.tryParse(
          entry['cgpa'].toString().replaceAll(RegExp(r'[^0-9.]'), ''));
      if (v != null) return v;
    }
  }
  return null;
}

/// Whether a student (branch + gpa, either possibly unknown) should see an
/// event. Missing profile data is inclusive — we never hide an event just
/// because the student hasn't filled in their branch or CGPA yet.
bool eventTargetsStudent(Map<String, dynamic> event,
    {String? branch, double? gpa}) {
  final branches = (event['targetBranches'] as List?)?.cast<String>();
  if (branches != null &&
      branches.isNotEmpty &&
      !branches.contains('all') &&
      branch != null &&
      branch.isNotEmpty &&
      !branches.map((b) => b.toLowerCase()).contains(branch.toLowerCase())) {
    return false;
  }
  final minGpa = (event['minGpa'] as num?)?.toDouble();
  if (minGpa != null && gpa != null && gpa < minGpa) return false;
  return true;
}
