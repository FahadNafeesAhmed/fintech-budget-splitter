# Frontend — Flutter Web App

Flutter web app wired to DartStream SaaS via the public
[`dartstream_client`](https://pub.dev/packages/dartstream_client) package.

## Features

- **Coin Catcher** — a playable game wired to live DartStream services
- Email/password sign-in via the DartStream SDK's one-call `signIn` / `signUp`
  (Identity Toolkit REST under the hood — no FlutterFire on the client)
- `Session` `ChangeNotifier` (no Riverpod, no `firebase_core` init)
- Feature flags gate gameplay; high score via cloud-save; `game_started` /
  `game_over` via reactive event logging
- Glassmorphic UI with a live DartStream engine panel

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry; session-driven routing |
| `lib/config.dart` | `FIREBASE_API_KEY` (`--dart-define`), `projectId`, `environmentId` |
| `lib/state/session.dart` | `DartStreamClient.signIn` / `signUp` wrapper |
| `lib/game/coin_catcher.dart` | The playable game (flag-gated, cloud-save, events) |
| `lib/services/game_service.dart` | Game cloud-save + reactive events |
| `lib/screens/login_screen.dart` | Sign in / create account UI |
| `lib/screens/home_screen.dart` | Game hero + DartStream engine panel |
| `test/game_service_test.dart` | MockClient-injected contract tests |

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
