# UniShip — Mobile App

Flutter companion app for the [UniShip web platform](https://github.com/mittahateclub/uniship).
It connects to the **same Firebase backend** (`uniship-4c1a1`) as the website, so all
accounts, internships, events, applications, resumes and results stay in sync.

## Features

### 🎓 Student portal
- **Dashboard** — today's saved events + quick access cards
- **College Space** — all university events & internships with search and bookmarks
- **Internship details & one-tap apply**, with application status tracking
- **Calendar** — month view of saved events with upcoming list & monthly summary
- **AI Resume Builder** — tailors your resume to any job description using Groq
  (Llama 3.3 70B), with matched-keyword highlighting
- **ATS Score** — live 100-point breakdown (contact, sections, keywords, depth, quality)
- **My Resumes** — save multiple variants, upload existing PDF/DOC, edit inline,
  export as a print-ready A4 PDF
- **Results** — scores, percentile, rank and anonymous peer leaderboard per test
- **Profile** — full structured portfolio editor (education, experience, projects,
  achievements, positions, extracurriculars) + profile photo upload

### 🏫 University admin portal
- Dashboard with live student / event / test counts
- Create & manage events (all 5 types: event, internship, hackathon, research, workshop)
- Approve / unapprove / delete tests
- Register student accounts (without being logged out, via a secondary auth instance)
- Student database with full-profile search, CGPA filter and detailed student view
- Admin profile

### 🛡️ Super admin portal
- Platform-wide stats
- Register / verify / delete universities
- Create university admins bound to verified universities
- Manage all students & admins (edit, reassign university, verify)

### ✨ App-wide
- **Dark / light mode** toggle (persisted), themed after the website's design system
- **Drawer navigation** — swipe from the left edge or tap the menu button
- Material 3, Inter typography, pull-to-refresh everywhere

> Per design, the app intentionally **excludes** the admin proctoring page and the
> student practice & test-taking pages — those remain on the web portal.

## Getting started

```bash
flutter pub get
flutter run
```

The Firebase config is bundled in `lib/firebase_options.dart` (same project as web).
For production-grade per-platform Firebase apps, optionally run `flutterfire configure`.

### AI resume builder key

The AI features call Groq directly from the device. Provide a key either way:

1. **In-app** — open the drawer → *AI Settings* → paste your key
   (free at [console.groq.com](https://console.groq.com)), or
2. **At build time** — `flutter run --dart-define=GROQ_API_KEY=gsk_...`

## Tech

- Flutter + Material 3, `provider` for state
- `firebase_core` / `firebase_auth` / `cloud_firestore` / `firebase_storage`
- `pdf` + `printing` for A4 resume export
- `google_fonts` (Inter UI, Source Serif resume preview)
