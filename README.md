# FinTech Budget Splitter

A full-stack Dart monorepo built as a sandbox for AI-assisted QA and debugging (DartCodeAI).

## What It Does

A real-time bill splitter — enter a total amount and number of people, get the split per person instantly. Built with Flutter (frontend), Dart Frog (backend), and Firebase (auth + Firestore).

## Architecture

```
fintech_tracker/
├── packages/shared_models/   # Shared Dart logic (DTOs + BudgetCalculator)
├── backend/                  # Dart Frog REST API (port 8080)
└── frontend/                 # Flutter web app with Firebase
```

## The Intentional Bug

`packages/shared_models/lib/src/budget_calculator.dart` uses **naive division** — splitting $10.00 by 3 returns `3.3333...` instead of `$3.33`. The unit test in `frontend/test/math_test.dart` expects exactly `3.33` and **will fail**, which is the intended DartCodeAI trap.

The fix: replace raw division with `(total / people * 100).round() / 100`.

## Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter + Riverpod + Google Fonts |
| Backend | Dart Frog |
| Auth | Firebase Authentication (email + anonymous) |
| Database | Cloud Firestore |
| Shared Logic | Pure Dart package |
| Testing | flutter_test + mockito + fake_cloud_firestore |

## Running Locally

**Backend**
```bash
cd backend
dart pub get
dart_frog dev
# Runs on http://localhost:8080
```

**Frontend**
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## Deploying

```bash
cd frontend
flutter build web --release
npx firebase-tools deploy
```
