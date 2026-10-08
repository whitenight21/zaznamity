import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import '../services/database_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize the database instance on startup
    await DatabaseHelper.instance.database;

    // Optional short delay for a smooth logo viewing experience
    await Future.delayed(const Duration(seconds: 0));

    if (!mounted) return;

    // Navigate to Dashboard screen with a smooth fade transition
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600), // Adjust speed here if desired
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 88, 47, 149),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display your custom logo asset matching pubspec.yaml
            ClipOval(
              child: Image.asset(
                'assets/ZaznamityLogo_onlyZwhite.png', 
                width: 180,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 36),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}