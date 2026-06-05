# Frontend — Flutter Web App

Flutter web app with glassmorphic UI, Firebase Auth, and Firestore integration.

## Features

- Glassmorphic card design with backdrop blur
- Email/password + anonymous authentication via Firebase
- Riverpod state management (sealed class state pattern)
- Micro-animations on button press and result reveal
- Saves each split to Firestore under the authenticated user
- Error handling via SnackBar (no crash dialogs)

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, Firebase init, auth routing |
| `lib/firebase_options.dart` | Firebase project config |
| `lib/screens/login_screen.dart` | Sign in / Sign up / Guest login UI |
| `lib/screens/home_screen.dart` | Main split calculator UI |
| `lib/services/api_client.dart` | HTTP client for Dart Frog backend |
| `lib/services/firebase_service.dart` | Firebase Auth + Firestore wrapper |
| `lib/providers/auth_provider.dart` | Riverpod auth + history stream providers |
| `test/math_test.dart` | **Unit tests — first test WILL FAIL (intentional bug)** |
| `test/firebase_mock_test.dart` | Mock Firestore stream tests — contains async race condition trap |

## Running

```bash
flutter pub get
flutter run -d chrome
```

## Testing (shows the intentional failures)

```bash
flutter test
```

## Deploying to Firebase Hosting

```bash
flutter build web --release
npx firebase-tools deploy
```
