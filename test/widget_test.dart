// Smoke test: the login screen renders without crashing when wired up with
// fresh (logged-out) providers, same shape main() uses.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:digital_settlement/services/auth_service.dart';
import 'package:digital_settlement/services/api_client.dart';
import 'package:digital_settlement/screens/login_screen.dart';

void main() {
  testWidgets('Login screen shows the sign-in form', (WidgetTester tester) async {
    final auth = AuthService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ProxyProvider<AuthService, ApiClient>(update: (_, auth, _) => ApiClient(auth)),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Digital Settlement'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
