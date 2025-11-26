import 'package:flutter/material.dart';
import 'pages/welcome_page.dart';

void main() {
  runApp(const HomeSenseApp());
}

class HomeSenseApp extends StatelessWidget {
  const HomeSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeSense',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
        useMaterial3: true,
      ),
      home: const WelcomePage(),
    );
  }
}
