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
fintech_tracker/
├── packages/
│   └── shared_models/              # Shared Dart logic (DTOs + BudgetCalculator)
│       ├── lib/src/
│       │   ├── transaction_model.dart
│       │   └── budget_calculator.dart  ⚠️ intentional naive division bug
│       └── pubspec.yaml
├── backend/                        # Dart Frog REST API (local dev only)
│   ├── routes/
│   │   ├── _middleware.dart        # CORS headers
│   │   └── api/transactions/index.dart
│   └── pubspec.yaml
├── frontend/                       # Flutter web app
│   ├── lib/
│   │   ├── config.dart             # AppConfig — DartStream microservice hosts
│   │   ├── api/
│   │   │   ├── firebase_auth.dart  # Identity Toolkit REST client
│   │   │   └── dartstream.dart     # DartStream API client
│   │   ├── state/
│   │   │   └── session.dart        # Session ChangeNotifier (DartStream pattern)
│   │   ├── screens/
│   │   │   ├── login_screen.dart   # SegmentedButton Sign In / Create Account
│   │   │   └── home_screen.dart    # Split calculator + DartStream integration
│   │   └── main.dart               # Session-driven routing
│   ├── test/
│   │   ├── math_test.dart          # ⚠️ WILL FAIL — the DartCodeAI trap
│   │   └── firebase_mock_test.dart # ⚠️ async race condition trap
│   └── pubspec.yaml
└── melos.yaml                      # Monorepo workspace
```

---

## The Intentional Bugs (DartCodeAI Traps)

This project is designed to be ingested by DartCodeAI as a QA stress test. Two intentional failures are baked in:

### Trap 1 — Floating-Point Rounding (`math_test.dart`)

`packages/shared_models/lib/src/budget_calculator.dart` uses naive division:

```dart
// BUG: returns 3.3333... not 3.33
final amountPerPerson = transaction.totalAmount / transaction.numberOfPeople;
```

The unit test expects exactly `3.33`. **It will fail.**

**The fix DartCodeAI should apply:**
```dart
final raw = transaction.totalAmount / transaction.numberOfPeople;
final amountPerPerson = (raw * 100).round() / 100;
```

### Trap 2 — Async Race Condition (`firebase_mock_test.dart`)

A `StreamController` is never closed, causing `toList()` to hang forever → test timeout. A `null` value is cast into a typed stream → type-cast exception buried in Firestore internals.

---

## DartStream Services Used

| Service | Endpoint | Usage |
|---------|---------|-------|
| `ds-auth` | `dev-apiauth.dartstream.io` | Signup, login, user/tenant resolution |
| `ds-platform` | `dev-apiplatform.dartstream.io` | Feature flags (`enable_rounding`, `split_history`) |
| `ds-experience` | `dev-apiexperience.dartstream.io` | Cloud-save persistence (`split_history` slot) |
| `ds-reactive` | `dev-apireactive.dartstream.io` | Event logging (`split_calculated`, `split_error`) |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Dart `>=3.0.0 <4.0.0` |
| Frontend Framework | Flutter Web |
| Backend Framework | DartStream Standard Engine |
| Local Dev Backend | Dart Frog |
| Auth | Firebase Identity Toolkit REST (no firebase_auth package) |
| Persistence | DartStream cloud-save (experience service) |
| Events | DartStream reactive event pipeline |
| Feature Flags | DartStream platform service (IntelliToggle-compatible) |
| Shared Logic | Pure Dart package (`shared_models`) |
| Testing | flutter_test + mockito |
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
flutter run -d chrome --dart-define=FIREBASE_API_KEY=<your_key>
```

The `FIREBASE_API_KEY` is your Firebase project's web API key. It is never committed.

---

## Testing (intentional failures included)

```bash
cd frontend
flutter test
# FAIL: math_test.dart — 3.3333 ≠ 3.33 (Trap 1)
# FAIL: firebase_mock_test.dart — async race condition (Trap 2)
```

---

## Deploying

```bash
cd frontend
flutter build web --release --dart-define=FIREBASE_API_KEY=<your_key>
npx firebase-tools deploy --only hosting
```

**Live:** https://fintech-budget-splitter.web.app

---

## Related

- [DartStream](https://github.com/aortem/dartstream) — the open-source Dart-native framework this app is built on
- [DartStream Founder Sample App](https://github.com/brian-chebon/dartstream-sample-app) — the reference implementation this project follows
