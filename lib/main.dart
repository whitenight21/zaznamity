import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/dashboard_screen.dart';
import 'services/database_helper.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const ZaznamityApp());
}

class ZaznamityApp extends StatefulWidget {
  const ZaznamityApp({super.key});

  @override
  State<ZaznamityApp> createState() => _ZaznamityAppState();
}

class _ZaznamityAppState extends State<ZaznamityApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zaznamity',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        primaryColor: const Color.fromARGB(255, 88, 47, 149),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 88, 47, 149)),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color.fromARGB(255, 129, 90, 213),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 129, 90, 213), brightness: Brightness.dark),
      ),
      home: SplashScreen(
        onThemeChanged: (isDark) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isDarkMode', isDark);
          setState(() {
            _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
          });
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const SplashScreen({super.key, required this.onThemeChanged});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isInitialized = false;
  bool _pinEnabled = false;
  String _savedPin = "1234";
  String _enteredPin = "";
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load preferences[cite: 10]
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _pinEnabled = prefs.getBool('biometricsEnabled') ?? false;
    _savedPin = prefs.getString('savedPin') ?? "1234";

    // Initialize the database instance on startup
    await DatabaseHelper.instance.database;

    // Optional short delay for a smooth startup view
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });

    // If PIN lock is disabled, navigate directly to dashboard
    if (!_pinEnabled) {
      _navigateToDashboard();
    }
  }

  void _navigateToDashboard() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => DashboardScreen(
          onThemeChanged: widget.onThemeChanged,
          onPinSettingsChanged: (enabled, pin) {
            setState(() {
              _pinEnabled = enabled;
              _savedPin = pin;
            });
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _onKeyTap(String value) {
    setState(() {
      if (_enteredPin.length < 4) {
        _enteredPin += value;
        if (_enteredPin.length == 4) {
          if (_enteredPin == _savedPin) {
            _navigateToDashboard();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Incorrect PIN')),
            );
            _enteredPin = "";
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 59, 30, 99),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Asset
                ClipOval(
                  child: Image.asset(
                    'assets/ZaznamityLogoFULL.jpg', 
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ZAZNAMITY',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'RECORD • TRACK • FOCUS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color.fromARGB(255, 157, 101, 255),
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Fixed-height container prevents any vertical shifting/dropping when loader disappears
                SizedBox(
                  height: 120,
                  child: Center(
                    child: !_isInitialized
                        ? const CircularProgressIndicator(color: Colors.white)
                        : (_pinEnabled
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Enter Passcode',
                                    style: TextStyle(fontSize: 14, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(4, (index) => Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: index < _enteredPin.length ? Colors.white : Colors.white.withValues(alpha: 0.3),
                                      ),
                                    )),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink()),
                  ),
                ),

                // PIN pad rows if initialized and enabled
                if (_isInitialized && _pinEnabled) ...[
                  const SizedBox(height: 12),
                  for (var row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', '⌫']])
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: row.map((val) {
                        if (val.isEmpty) return const SizedBox(width: 60, height: 60);
                        return Container(
                          margin: const EdgeInsets.all(6),
                          width: 60,
                          height: 60,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const CircleBorder(),
                            ),
                            onPressed: () {
                              if (val == '⌫') {
                                if (_enteredPin.isNotEmpty) {
                                  setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
                                }
                              } else {
                                _onKeyTap(val);
                              }
                            },
                            child: Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}