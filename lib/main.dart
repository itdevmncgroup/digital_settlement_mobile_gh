import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await loadApiBaseUrlOverride();
  runApp(const DigitalSettlementApp());
}

class DigitalSettlementApp extends StatelessWidget {
  const DigitalSettlementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..loadFromStorage()),
        ProxyProvider<AuthService, ApiClient>(update: (_, auth, _) => ApiClient(auth)),
      ],
      child: MaterialApp(
        title: 'Digital Settlement',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(),
        themeMode: ThemeMode.light,
        home: const AuthGate(),
      ),
    );
  }
}

/// Switches between the login screen and the main app shell based on session
/// state - mirrors web-admin's AppShell redirect-to-/login-when-logged-out.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isLoggedIn ? const HomeShell() : const LoginScreen();
  }
}
