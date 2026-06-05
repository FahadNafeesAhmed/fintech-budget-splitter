import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'state/session.dart';

void main() {
  runApp(const BudgetSplitterApp());
}

/// App entry point following the DartStream founder sample app pattern:
///   - No firebase_core init — auth is handled via Identity Toolkit REST
///   - Session is a ChangeNotifier passed through the widget tree
///   - Routing is driven by session.status (no Riverpod, no StreamProvider)
class BudgetSplitterApp extends StatefulWidget {
  const BudgetSplitterApp({super.key});

  @override
  State<BudgetSplitterApp> createState() => _BudgetSplitterAppState();
}

class _BudgetSplitterAppState extends State<BudgetSplitterApp> {
  final _session = Session();

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
      title: 'Budget Splitter — DartStream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: _session.isSignedIn
          ? HomeScreen(session: _session)
          : LoginScreen(session: _session),
    );
  }
}
