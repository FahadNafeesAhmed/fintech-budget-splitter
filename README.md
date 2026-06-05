# FinTech Budget Splitter

A full-stack Dart monorepo built as a sandbox for AI-assisted QA and debugging (DartCodeAI).

![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat&logo=dart&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?style=flat&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth_%2B_Firestore-FFCA28?style=flat&logo=firebase&logoColor=black)
![Dart Frog](https://img.shields.io/badge/Dart_Frog-Backend-13B9FD?style=flat&logo=dart&logoColor=white)
![Riverpod](https://img.shields.io/badge/Riverpod-State_Management-00BCD4?style=flat)
![Melos](https://img.shields.io/badge/Melos-Monorepo-6A1B9A?style=flat)

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

## Languages & Frameworks

| Category | Technology | Version |
|----------|-----------|---------|
| Language | Dart | `>=3.0.0 <4.0.0` |
| Frontend Framework | Flutter | `3.22+` |
| Backend Framework | Dart Frog | `^1.2.x` |
| State Management | flutter_riverpod | `^2.6.x` |
| Authentication | Firebase Auth | `^5.3.x` |
| Database | Cloud Firestore | `^5.4.x` |
| UI Fonts | Google Fonts | `^6.x` |
| Monorepo Tooling | Melos | workspace |
| Testing | flutter_test + mockito | `^5.4.x` |
| Mock Firestore | fake_cloud_firestore | `^3.0.x` |
| HTTP Client | package:http | `^1.2.x` |

## Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter Web + Riverpod + Google Fonts |
| Backend | Dart Frog REST API |
| Auth | Firebase Authentication (email/password + anonymous) |
| Database | Cloud Firestore |
| Shared Logic | Pure Dart package (shared between frontend + backend) |
| Testing | flutter_test + mockito + fake_cloud_firestore |
| Deployment | Firebase Hosting |

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

## Testing (intentional failures included)

```bash
cd frontend
flutter test
# Expect: math_test.dart FAIL — 3.3333 ≠ 3.33 (the DartCodeAI trap)
# Expect: firebase_mock_test.dart FAIL — async race condition trap
```

## Deploying

```bash
cd frontend
flutter build web --release
npx firebase-tools deploy
```
