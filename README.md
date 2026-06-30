# Coin Catcher — a DartStream Sample App

![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat&logo=dart&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?style=flat&logo=flutter&logoColor=white)
![DartStream](https://img.shields.io/badge/DartStream-Backend_Framework-13B9FD?style=flat)
![Firebase](https://img.shields.io/badge/Firebase-Identity_Toolkit-FFCA28?style=flat&logo=firebase&logoColor=black)
![Melos](https://img.shields.io/badge/Melos-Monorepo-6A1B9A?style=flat)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)

> A full-stack Dart sample app showcasing **DartStream** — a playable arcade game
> plus a budget splitter, both driven live by DartStream's authentication,
> feature-flag, persistence, and reactive-event services. Also a sandbox for
> AI-assisted QA and debugging with DartCodeAI.

**Live Demo →** https://sample-app-fahad-ahmed.web.app

---

## What It Does

The headline is **Coin Catcher** — a playable game wired end-to-end to live
DartStream services (not decoupled UI):

- 🪙 **Tap the falling coins** before they drop; 3 misses and it's game over.
- **Flag-gated gameplay** — the `double_score` (2× points) and `hard_mode`
  (faster coins) feature flags, read from the platform service, change real
  mechanics.
- **Cloud-save progress** — the high score persists to a single cloud-save
  snapshot (slot `game_state`, last-write-wins).
- **Reactive event logging** — `game_started` / `game_over` events fire to the
  reactive pipeline on real gameplay.

It also ships a **budget splitter** as a second feature: enter a total and a
number of people, and it calculates each share, saves it to DartStream
persistence, and logs the event — demonstrating the same services from a
different surface.

## Authentication & OAuth grants

This sample uses **two** DartStream auth paths, deliberately:

- **User session (the app):** the Flutter web client signs in with email/
  password via `DartStreamClient.signIn` / `signUp` (Firebase Identity Toolkit
  → `ds-auth` onboarding), against the `DartStreamConfig.dev()` backend. This is
  the grant wired to all in-app service calls (platform, experience, reactive).
- **OAuth2 client-credentials (server-to-server probe):** `bin/oauth2_deepdive.dart`
  exchanges a `client_id` + `client_secret` for a DartStream-signed Bearer JWT
  (`grant_type=client_credentials`) and calls the services with no interactive
  user — the machine-to-machine path from ticket #96. Credentials come from
  `OAUTH2_CLIENT_ID` / `OAUTH2_CLIENT_SECRET` env vars and are **never
  committed**. A `clientSecret` is server-only — never embedded in the browser
  bundle.

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
    user/tenant)   game_state +    game_started,
                   profile)        game_over)
```

> `ds-platform` feature flags (`double_score`, `hard_mode`) are read at
> startup and gate the game's behavior; the surface is also exercised by
> `bin/platform_deepdive.dart` as a contract probe.

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
│   ├── experience_deepdive.dart    # profiles, cloud-save, inventory
│   ├── reactive_deepdive.dart      # events, streaming channels, notifications
│   ├── persistence_deepdive.dart   # database, storage, logging
│   └── oauth2_deepdive.dart        # client-credentials token → service calls
├── .env.example                    # config template — copy to .env (gitignored)
├── pubspec.yaml                    # deps for the bin/ CLIs (http only)
├── .github/workflows/ci.yml        # analyze bin, analyze+test+build frontend
├── frontend/                       # Flutter web game (the customer reference,
│   │                                 consumes the dartstream_client SDK)
│   ├── lib/
│   │   ├── config.dart             # FIREBASE_API_KEY + projectId/environmentId
│   │   ├── state/
│   │   │   └── session.dart        # DartStreamClient.signIn / signUp wrapper
│   │   ├── game/
│   │   │   └── coin_catcher.dart   # the playable game (flag-gated, cloud-save, events)
│   │   ├── services/
│   │   │   └── game_service.dart   # game cloud-save (high score) + reactive events
│   │   ├── screens/
│   │   │   ├── login_screen.dart   # Sign In / Create Account (Coin Catcher themed)
│   │   │   └── home_screen.dart    # game hero + DartStream engine panel
│   │   └── main.dart               # Session-driven routing
│   ├── test/
│   │   └── game_service_test.dart  # MockClient-injected contract tests
│   └── pubspec.yaml
└── melos.yaml                      # workspace
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
dart run bin/experience_deepdive.dart   # profiles, cloud-save, inventory
dart run bin/reactive_deepdive.dart     # events, streaming, notifications
dart run bin/persistence_deepdive.dart  # database, storage, logging
dart run bin/oauth2_deepdive.dart       # OAuth2 client-credentials (needs OAUTH2_CLIENT_ID/SECRET)
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
| `ds-platform` | `client.platform.listFeatureFlags` | Feature flags (`double_score`, `hard_mode`) that gate game behavior |
| `ds-experience` | `client.experience.loadCloudSave` / `saveCloudSave` + `profile` | High-score cloud-save (slot `game_state`, single snapshot LWW) + user profile |
| `ds-reactive` | `client.reactive.logEvent` | `game_started` / `game_over` events |

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
| Game | Pure Flutter (`Ticker` + widgets — no game-engine dependency) |
| Testing | `flutter_test` + `package:http` `MockClient` |
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
flutter build web --release --dart-define=FIREBASE_API_KEY=<your_web_api_key>
npx firebase-tools deploy --only hosting
```

**Live:** https://sample-app-fahad-ahmed.web.app

---

## Related

- [DartStream](https://github.com/aortem/dartstream) — the open-source Dart-native framework this app is built on
- [DartStream Founder Sample App](https://github.com/brian-chebon/dartstream-sample-app) — the reference implementation this project follows
