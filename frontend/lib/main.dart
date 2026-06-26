import 'package:flutter/material.dart';

import 'bootstrap.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'state/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prefer Firebase Hosting's auto-served /__/firebase/init.json (per the
  // dartstream_client README), fall back to the const in AppConfig.
  final firebaseApiKey = await loadFirebaseApiKey();
  runApp(BudgetSplitterApp(firebaseApiKey: firebaseApiKey));
}

/// App entry point following the DartStream founder sample app pattern:
///   - Auth is handled by `dartstream_client` (Identity Toolkit REST → ds-auth)
///   - Session is a ChangeNotifier passed through the widget tree
///   - Routing is driven by session.status (no Riverpod, no StreamProvider)
class BudgetSplitterApp extends StatefulWidget {
  const BudgetSplitterApp({super.key, required this.firebaseApiKey});

  final String firebaseApiKey;

  @override
  State<BudgetSplitterApp> createState() => _BudgetSplitterAppState();
}

class _BudgetSplitterAppState extends State<BudgetSplitterApp> {
  late final Session _session = Session(firebaseApiKey: widget.firebaseApiKey);

  @override
  void initState() {
    super.initState();
    _session.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coin Catcher — DartStream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: _session.isSignedIn
          ? HomeScreen(session: _session)
          : LoginScreen(session: _session),
    );
  }
}
