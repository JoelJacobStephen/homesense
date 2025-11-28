import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'start_setup_page.dart';
import 'home_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    // Navigate after brief splash: if calibrated -> Suggestions, else Start Setup
    Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      bool calibrated = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        calibrated = prefs.getBool('calibrated') ?? false;
      } catch (_) {
        // Plugin not available yet (e.g., after hot restart). Default to not calibrated.
        calibrated = false;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => calibrated ? const HomePage() : const StartSetupPage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final deepBlue = const Color(0xFF0D47A1);
    final lighterBlue = const Color(0xFF1976D2);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [lighterBlue.withOpacity(0.9), deepBlue],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome to HomeSense',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Where the Future is Reality',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
