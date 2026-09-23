import 'package:flutter_test/flutter_test.dart';
import 'package:fit_to_beat/main.dart';
import 'package:fit_to_beat/presentation/screens/rhythm_game_screen.dart';

void main() {
  testWidgets('Fit to Beat app loads RhythmGameScreen smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FitToBeatApp());
    await tester.pump();

    // Verify main rhythm game screen is present
    expect(find.byType(RhythmGameScreen), findsOneWidget);
  });
}
