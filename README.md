# FinTech Budget Splitter

![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat&logo=dart&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?style=flat&logo=flutter&logoColor=white)
![DartStream](https://img.shields.io/badge/DartStream-Backend_Framework-13B9FD?style=flat)
![Firebase](https://img.shields.io/badge/Firebase-Identity_Toolkit-FFCA28?style=flat&logo=firebase&logoColor=black)
![Melos](https://img.shields.io/badge/Melos-Monorepo-6A1B9A?style=flat)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

> A full-stack Dart monorepo demonstrating DartStream's authentication, persistence, reactive event, and platform feature-flag services — built as a sandbox for AI-assisted QA and debugging with DartCodeAI.

**Live Demo →** https://fintech-budget-splitter.web.app

---

## What It Does

A real-time bill splitter. Enter a total amount and number of people — the app instantly calculates each person's share, saves the result to DartStream's persistence layer, and logs the event to DartStream's reactive pipeline.

---

## DartStream Architecture

This project follows the [DartStream](https://github.com/aortem/dartstream) open-source framework pattern exactly as demonstrated in the official founder sample app.

```
┌─────────────────────────────────────────────────────┐
│                  Flutter Web Client                 │
│                                                     │
│  FirebaseAuthRest ──► Identity Toolkit REST API     │
│       │                                             │
│       ▼  (Firebase ID Token)                        │
│  DartstreamApi ──► Bearer Token ──► DartStream      │
│                                     Microservices   │
└─────────────────────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
   ds-auth service  ds-platform    ds-experience
   (verify token,   (feature flags  (cloud-save,
   user/tenant IDs)  enable_rounding  split_history)
                    split_history)
                          │
                          ▼
                   ds-reactive
                   (event log:
                   split_calculated,
                   split_error)
```

### Auth Flow (DartStream Pattern)

1. Browser calls Firebase Identity Toolkit REST API directly — no `firebase_auth` package, no JS SDK
2. Identity Toolkit returns a Firebase ID token
3. `DartstreamApi` attaches token as `Authorization: Bearer <token>`
4. DartStream's `ds-auth` service verifies the token server-side using the admin SDK
5. Returns `userId` + `tenantId` — all subsequent calls are scoped to the tenant

---

## Monorepo Structure

```
fintech-budget-splitter/
├── packages/
│   └── shared_models/              # Shared Dart logic (DTOs + BudgetCalculator)
│       ├── lib/src/
│       │   ├── transaction_model.dart
│       │   └── budget_calculator.dart
│       └── pubspec.yaml
├── backend/                        # Optional Dart Frog illustration — NOT on the
│   │                                 DartStream path; the frontend does NOT call it
│   └── routes/
├── frontend/                       # Flutter web app (the DartStream sample)
│   ├── lib/
│   │   ├── config.dart             # FIREBASE_API_KEY + projectId/environmentId
│   │   ├── state/
│   │   │   └── session.dart        # DartStreamClient.signIn / signUp wrapper
│   │   ├── screens/
│   │   │   ├── login_screen.dart   # Sign In / Create Account
│   │   │   └── home_screen.dart    # Calculator + experience/reactive integration
│   │   └── main.dart               # Session-driven routing
│   ├── test/
│   │   └── math_test.dart          # BudgetCalculator unit tests
│   └── pubspec.yaml
└── melos.yaml                      # Monorepo workspace
```

---

## DartStream Services Used

All wiring goes through the public
[`dartstream_client`](https://pub.dev/packages/dartstream_client) package.
Host resolution lives in the SDK (`DartStreamConfig.dev()` /
`DartStreamConfig.prod()` / `DartStreamConfig.local()`), so the hosts below are
for reference only — no host strings are hard-coded in this app.

| Service | Used via | Usage in this sample |
|---------|---------|----------------------|
| `ds-auth` | `client.auth` (one-call `signIn` / `signUp`) | Sign-up, sign-in, user/tenant resolution |
| `ds-platform` | `client.platform` | Feature flags (`enable_rounding`, `split_history`) |
| `ds-experience` | `client.experience.loadCloudSave` / `saveCloudSave` | Cloud-save `split_history` slot (read-modify-write list pattern) |
| `ds-reactive` | `client.reactive.logEvent` | `split_calculated` / `split_error` events |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language / SDK floor | Dart `>=3.12.0 <4.0.0`, Flutter `>=3.44.0` |
| Frontend Framework | Flutter Web |
| Backend | DartStream SaaS via `dartstream_client` |
| Auth | DartStream SDK (Identity Toolkit REST → ds-auth) — no `firebase_auth` |
| Persistence | DartStream cloud-save (experience service) |
| Events | DartStream reactive event pipeline |
| Feature Flags | DartStream platform service |
| Shared Logic | Pure Dart package (`shared_models`) |
| Testing | `flutter_test` |
| Monorepo | Melos |
| Deployment | Firebase Hosting |

---

## Running Locally

**Backend (Dart Frog — local dev only)**
```bash
cd backend
dart pub get
dart_frog dev
# → http://localhost:8080
```

**Frontend**
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

The Firebase **web** API key for this sample project is embedded in
`lib/config.dart` and `web/index.html`. Firebase web API keys identify a
project to Google's APIs and are intended to be public — security is enforced
by Firebase rules and the authorized-domain list, not by hiding the key.
To point the app at a different Firebase project at build time, override it:

```bash
flutter run -d chrome --dart-define=FIREBASE_API_KEY=<other_key>
```

---

## Testing

```bash
cd frontend
flutter test
```

---

## Deploying

```bash
cd frontend
flutter build web --release
npx firebase-tools deploy --only hosting
```

**Live:** https://fintech-budget-splitter.web.app

---

## Related

- [DartStream](https://github.com/aortem/dartstream) — the open-source Dart-native framework this app is built on
- [DartStream Founder Sample App](https://github.com/brian-chebon/dartstream-sample-app) — the reference implementation this project follows
