import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'demo.dart';
import 'state/app_state.dart';
import 'state/conversation_store.dart';
import 'ui/chats_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CloakApp());
}

class CloakApp extends StatelessWidget {
  const CloakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        ChangeNotifierProvider(create: (_) => ConversationStore()..init()),
      ],
      child: MaterialApp(
        title: 'Cloak',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _demoApplied = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final store = context.watch<ConversationStore>();
    if (!app.ready || !store.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (kCloakDemo && !_demoApplied) {
      _demoApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => applyDemo(app, store));
    }
    return const ChatsScreen();
  }
}
