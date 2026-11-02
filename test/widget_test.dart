import 'package:flutter_test/flutter_test.dart';
import 'package:number_slide_pro/main.dart';

void main() {
  testWidgets('Game app renders title', (tester) async {
    await tester.pumpWidget(const PuzzleApp(online: false));
    expect(find.text('Number Slide Pro'), findsOneWidget);
  });
}
