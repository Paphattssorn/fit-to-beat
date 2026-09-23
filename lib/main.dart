import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'presentation/screens/rhythm_game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for standard fitness tracking setup
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const FitToBeatApp());
}

class FitToBeatApp extends StatelessWidget {
  const FitToBeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fit to Beat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF2A85),
          surface: Color(0xFF121212),
        ),
        useMaterial3: true,
      ),
      home: const RhythmGameScreen(),
    );
  }
}
