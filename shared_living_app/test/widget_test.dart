import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/features/auth/data/mock_auth_repository.dart';
import 'package:shared_living_app/features/auth/data/token_storage.dart';
import 'package:shared_living_app/features/shared_living/data/repositories/mock_shared_living_repository.dart';
import 'package:shared_living_app/main.dart';

void main() {
  testWidgets('App renders LoginScreen with professional auth UI on start', (WidgetTester tester) async {
    final tokenStorage = TokenStorage(inMemoryOnly: true);
    final authRepository = MockAuthRepository(tokenStorage: tokenStorage);
    final sharedLivingRepository = MockSharedLivingRepository(latency: Duration.zero);

    await tester.pumpWidget(MyApp(
      authRepository: authRepository,
      sharedLivingRepository: sharedLivingRepository,
    ));

    // Allow checkAuthStatus Future and microtasks to complete
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump();

    expect(find.text('Shared living, settled smoothly.'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('EMAIL ADDRESS'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('Sign In to Hisab'), findsOneWidget);
  });
}
