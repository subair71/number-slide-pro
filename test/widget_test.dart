import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:number_slide_pro/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('The game renders before an online leaderboard is available', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'plugins.flutter.io/google_mobile_ads',
      (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
    );
    await tester.pumpWidget(const PuzzleApp());
    await tester.pump();
    expect(find.text('Number Slide'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('New Game'), findsOneWidget);
  });
}
