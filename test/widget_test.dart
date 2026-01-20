// Basic Flutter widget test for Agro Sirius.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agro_sirius/main.dart';
import 'package:agro_sirius/services/meshtastic_service.dart';

void main() {
  testWidgets('App loads and shows Agro Sirius title', (WidgetTester tester) async {
    // Build our app with provider and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MeshtasticService(),
        child: const AgroSiriusApp(),
      ),
    );

    // Wait for any async operations
    await tester.pumpAndSettle();

    // Verify that the app title is displayed.
    expect(find.text('Agro Sirius'), findsOneWidget);

    // Verify that navigation bar items exist.
    expect(find.text('Siembra'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
  });
}
