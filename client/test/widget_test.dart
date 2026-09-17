import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:asistiq_client/main.dart';
import 'package:asistiq_client/features/auth/state/auth_notifier.dart';
import 'package:asistiq_client/features/auth/state/auth_state.dart';
import 'package:asistiq_client/shared/api/api_client.dart';

class StubAuthNotifier extends AuthNotifier {
  StubAuthNotifier() : super(ApiClient()) {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  Future<void> checkAuth() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('App smoke test loads login screen for unauthenticated session', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => StubAuthNotifier()),
        ],
        child: const AsistIQApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to AsistIQ'), findsOneWidget);
  });
}
