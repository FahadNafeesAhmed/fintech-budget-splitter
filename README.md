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
│  dartstream_client SDK                              │
│    DartStreamClient.signIn / signUp                 │
│       │   (SDK handles Identity Toolkit + ds-auth   │
│       │    onboarding; returns a DartStreamSession) │
│       ▼                                             │
│  client.experience / client.reactive                │
└───────────────────────┬─────────────────────────────┘
                        │  (authenticated session)
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
     ds-auth       ds-experience   ds-reactive
   (sign in/up,   (cloud-save     (event log:
    user/tenant)   split_history)  split_calculated,
                                   split_error)
```

> `ds-platform` (feature flags / projects) is not consumed by the calculator;
> it is exercised independently by `bin/platform_deepdive.dart` as a contract
> probe.

### Auth Flow (DartStream Pattern)

1. The app calls `DartStreamClient.signIn` / `signUp` from the first-party
   `dartstream_client` SDK — no `firebase_auth` package, no hand-rolled REST.
2. The SDK performs the Firebase Identity Toolkit exchange and ds-auth
   onboarding internally, returning an authenticated `DartStreamSession`.
3. All subsequent service calls (`client.experience`, `client.reactive`) are
   made through that session, scoped to the resolved user / tenant.

---

## Monorepo Structure

```
fintech-budget-splitter/
├── bin/                            # headless Dart CLIs (contract probes)
│   ├── _shared.dart                # Firebase Identity Toolkit + ds-auth onboarding
│   ├── smoke.dart                  # one representative contract per service
│   ├── auth_deepdive.dart          # full ds-auth surface
│   ├── platform_deepdive.dart      # feature-flags, projects, api-keys, team, …
│   ├── experience_deepdive.dart    # profiles, cloud-save (split_history), inventory
│   ├── reactive_deepdive.dart      # events, streaming channels, notifications
│   └── persistence_deepdive.dart   # database, storage, logging
├── .env.example                    # config template — copy to .env (gitignored)
├── pubspec.yaml                    # deps for the bin/ CLIs (http only)
├── .github/workflows/ci.yml        # analyze bin + shared_models, build frontend
├── packages/
│   └── shared_models/              # Shared Dart logic (DTOs + BudgetCalculator)
│       ├── lib/src/
│       │   ├── transaction_model.dart
│       │   └── budget_calculator.dart
│       └── pubspec.yaml
├── frontend/                       # Flutter web app (the customer reference,
│   │                                 consumes the dartstream_client SDK)
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

The split mirrors the DartStream founder sample app: `frontend/` is the **customer reference** that consumes the first-party `dartstream_client` SDK exactly as a real client would, while `bin/` is a set of **low-level contract probes** that hand-write Firebase REST + raw `Authorization`/`X-Tenant-ID` headers with `package:http` so they verify the deployed HTTP contracts independently of the SDK. Don't copy `bin/` into an app.

### Running the smoke + deep-dive CLIs

```bash
cp .env.example .env
# fill in FIREBASE_API_KEY + TEST_EMAIL + TEST_PASSWORD
set -a && source .env && set +a

dart pub get
dart run bin/smoke.dart                 # 10-endpoint health check across all 5 services
dart run bin/auth_deepdive.dart         # full ds-auth surface (PASS/FAIL/SKIP table)
dart run bin/platform_deepdive.dart     # feature-flags, projects, api-keys, team
dart run bin/experience_deepdive.dart   # profiles, cloud-save (split_history), inventory
dart run bin/reactive_deepdive.dart     # events, streaming, notifications
dart run bin/persistence_deepdive.dart  # database, storage, logging
```

Destructive endpoints (DELETE user, revoke-all-sessions, invitation emails, member-role changes) are skipped by default. Re-run with `DEEPDIVE_DESTRUCTIVE=1` to include them.

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
| `ds-platform` | `client.platform` | Feature-flag / project surface exercised by `bin/platform_deepdive.dart` (not consumed by the calculator) |
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

The app is a single Flutter web client that talks to DartStream SaaS via the
`dartstream_client` SDK. There is no local backend to run.

```bash
cd frontend
flutter pub get
flutter run -d chrome --web-port=3000 --dart-define=FIREBASE_API_KEY=<your_web_api_key>
```

> ⚠️ **The port matters.** The Firebase web API key is HTTP-referrer-restricted
> in Google Cloud, and `http://localhost:3000` is the allowlisted dev origin.
> From any other origin — including a deployed `*.web.app` host — the browser blocks the
> ds-auth call and the login button surfaces *"Could not reach DartStream
> (CORS or network)"*. Always launch with `--web-port=3000` locally; for a
> hosted demo, the deployed origin must be whitelisted by the DartStream team
> (typically by deploying under the official sample-apps project).

**The Firebase web API key is not committed.** Pass it at run/build time with
`--dart-define=FIREBASE_API_KEY=<your_web_api_key>`. When the app is served
from Firebase Hosting it instead loads the public config from
`/__/firebase/init.json` automatically (see `lib/bootstrap.dart`), so no key
is needed there. Firebase web API keys identify a project to Google's APIs and
are public-by-design — security is enforced by Firebase rules and the
authorized-domain list — but this sample keeps it out of source control per
the DartStream "no committed keys" house standard.

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
