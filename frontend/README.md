# Frontend — Flutter Web App

Flutter web app wired to DartStream SaaS via the public
[`dartstream_client`](https://pub.dev/packages/dartstream_client) package.

## Features

- Glassmorphic card design with backdrop blur
- Email/password sign-in via the DartStream SDK's one-call `signIn` / `signUp`
  (Identity Toolkit REST under the hood — no FlutterFire on the client)
- `Session` `ChangeNotifier` (no Riverpod, no `firebase_core` init)
- Cloud-save history via `client.experience` (read-modify-write list pattern)
- Reactive event logging via `client.reactive`
- Real `HTTP <code>: <body>` surfaced on save/event failures (no hidden errors)

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry; session-driven routing |
| `lib/config.dart` | `FIREBASE_API_KEY` (`--dart-define`), `projectId`, `environmentId` |
| `lib/state/session.dart` | `DartStreamClient.signIn` / `signUp` wrapper |
| `lib/screens/login_screen.dart` | Sign in / create account UI |
| `lib/screens/home_screen.dart` | Calculator + cloud-save + reactive event log |
| `test/math_test.dart` | Unit tests for `BudgetCalculator` |

## Running

```bash
flutter pub get
flutter run -d chrome --web-port=3000 --dart-define=FIREBASE_API_KEY=<your_web_api_key>
```

> ⚠️ The `--web-port=3000` flag is required: the Firebase web API key is
> HTTP-referrer-restricted in Google Cloud and `http://localhost:3000` is the
> allowlisted dev origin. From any other origin — including a deployed
> `*.web.app` host — the browser blocks
> the ds-auth POST and the login banner shows *"Could not reach DartStream
> (CORS or network)"*. A hosted demo needs its origin whitelisted by the
> DartStream team.

The Firebase web API key is **not committed** — pass it with
`--dart-define=FIREBASE_API_KEY=<your_web_api_key>` locally. On Firebase
Hosting, `lib/bootstrap.dart` loads the public config from
`/__/firebase/init.json` automatically, so no key is needed for the deployed
build.

## Testing

```bash
flutter test
```

## Deploying to Firebase Hosting

```bash
flutter build web --release
npx firebase-tools deploy --only hosting
```
