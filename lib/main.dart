import 'dart:async';
import 'dart:developer' as developer;
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'services/deep_link_handler.dart';
import 'services/notifications_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

/// No named-route table exists in this app (plain Navigator.push everywhere -
/// see home_shell.dart) - this is how a push-notification tap or an incoming
/// deep link reaches a NavigatorState without a BuildContext of its own.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await loadApiBaseUrlOverride();

  // Inert until google-services.json (Android) / GoogleService-Info.plist
  // (iOS) are added - Firebase.apps stays empty and every push/notification
  // code path downstream (see push_notifications.dart) no-ops instead of
  // throwing, so the app runs fine before that's set up.
  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    developer.log('Firebase.initializeApp failed - push notifications disabled', name: 'notifications', error: e, stackTrace: st);
  }

  runApp(const DigitalSettlementApp());
}

class DigitalSettlementApp extends StatefulWidget {
  const DigitalSettlementApp({super.key});

  @override
  State<DigitalSettlementApp> createState() => _DigitalSettlementAppState();
}

class _DigitalSettlementAppState extends State<DigitalSettlementApp> {
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _listenForDeepLinks();
  }

  // Handles both the `digitalsettlement://...` custom scheme (works
  // immediately, no domain verification needed) and, once assetlinks.json/
  // apple-app-site-association are hosted and verified, `https://<app-domain>/...`
  // App Links / Universal Links landing here instead of the browser.
  Future<void> _listenForDeepLinks() async {
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      // On Flutter web, getInitialLink() returns the page's own load URL
      // (there's no separate OS-level "app link intent" to distinguish it
      // from) - a plain `flutter run -d chrome` at the bare root would
      // otherwise be treated as an unrecognized deep link and fall through
      // to handleDeepLink's Approvals-inbox default on every cold boot.
      if (initial != null && initial.pathSegments.isNotEmpty) {
        handleDeepLink(rootNavigatorKey, '${initial.path}?${initial.query}');
      }
    } catch (e, st) {
      developer.log('Failed to read initial deep link', name: 'deeplink', error: e, stackTrace: st);
    }
    _linkSubscription = appLinks.uriLinkStream.listen(
      (uri) => handleDeepLink(rootNavigatorKey, '${uri.path}?${uri.query}'),
      onError: (e, st) => developer.log('Deep link stream error', name: 'deeplink', error: e, stackTrace: st),
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..loadFromStorage()),
        ProxyProvider<AuthService, ApiClient>(update: (_, auth, _) => ApiClient(auth)),
        ChangeNotifierProxyProvider<ApiClient, NotificationsService>(
          create: (context) => NotificationsService(context.read<ApiClient>()),
          update: (_, api, _) => NotificationsService(api),
        ),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
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
