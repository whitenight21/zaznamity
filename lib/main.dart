// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
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

class _ZaznamityAppState extends State<ZaznamityApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLocked = false;
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLockSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialLockSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pinEnabled = prefs.getBool('biometricsEnabled') ?? false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    
    final prefs = await SharedPreferences.getInstance();
    final securityEnabled = prefs.getBool('biometricsEnabled') ?? false;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (securityEnabled) {
        setState(() {
          _isLocked = true;
          _pinEnabled = true;
        });
      }
    }
  }

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
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            // Background lock overlay
            if (_isLocked)
              SplashScreen(
                isBackgroundLock: true,
                onUnlocked: () {
                  setState(() {
                    _isLocked = false;
                  });
                },
                onThemeChanged: (isDark) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isDarkMode', isDark);
                  setState(() {
                    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
                  });
                },
              ),
          ],
        );
      },
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
  final bool isBackgroundLock;
  final VoidCallback? onUnlocked;

  const SplashScreen({
    super.key, 
    required this.onThemeChanged,
    this.isBackgroundLock = false,
    this.onUnlocked,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _pinEnabled = false;
  String _savedPin = "1234";
  String _enteredPin = "";
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _useFingerprint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Automatically trigger biometrics again when screen turns back on / app resumes
    if (state == AppLifecycleState.resumed && _useFingerprint && (_pinEnabled || widget.isBackgroundLock)) {
      _triggerBiometricAuth();
    }
  }

  Future<void> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load preferences
    _pinEnabled = prefs.getBool('biometricsEnabled') ?? false;
    _useFingerprint = prefs.getBool('useFingerprint') ?? false;
    _savedPin = prefs.getString('savedPin') ?? "1234";

    // Initialize the database instance on startup
    await DatabaseHelper.instance.database;

    // Optional short delay for a smooth startup view
    if (!widget.isBackgroundLock) {
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });

    // If security lock is disabled and it's not a background lock, navigate directly to dashboard
    if (!_pinEnabled && !widget.isBackgroundLock) {
      _navigateToDashboard();
    } else if (_useFingerprint && (_pinEnabled || widget.isBackgroundLock)) {
      // Use post-frame callback to trigger biometrics the exact moment the frame is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _triggerBiometricAuth();
        }
      });
    }
  }

  Future<void> _triggerBiometricAuth() async {
    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Zaznamity',
      );
      if (authenticated) {
        _navigateToDashboard();
      }
    } catch (e) {
      debugPrint('Biometric error: $e');
    }
  }

  void _navigateToDashboard() {
    if (widget.isBackgroundLock && widget.onUnlocked != null) {
      widget.onUnlocked!();
      return;
    }

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
                    width: 190,
                    height: 190,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                // Title
                const Text(
                  'ZAZNAMITY',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                // Subtitle
                const Text(
                  'RECORD • TRACK • FOCUS',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color.fromARGB(255, 157, 101, 255),
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Fixed-height container prevents any vertical shifting/dropping when loader disappears
                SizedBox(
                  height: 90,
                  child: Center(
                    child: (!_isInitialized && !widget.isBackgroundLock)
                        ? const CircularProgressIndicator(color: Colors.white)
                        : ((_pinEnabled || widget.isBackgroundLock) && !_useFingerprint
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Enter Passcode',
                                    style: TextStyle(fontSize: 14, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(4, (index) => Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: index < _enteredPin.length ? Colors.white : Colors.white.withValues(alpha: 0.3),
                                      ),
                                    )),
                                  ),
                                ],
                              )
                            : (_useFingerprint && (_pinEnabled || widget.isBackgroundLock)
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Biometric Authentication Required',
                                        style: TextStyle(fontSize: 14, color: Colors.white70),
                                      ),
                                      const SizedBox(height: 10),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: _triggerBiometricAuth,
                                        icon: const Icon(Icons.fingerprint),
                                        label: const Text('Scan Fingerprint'),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink())),
                  ),
                ),

                // PIN pad rows if initialized and enabled and not using fingerprint
                if ((_isInitialized || widget.isBackgroundLock) && (_pinEnabled || widget.isBackgroundLock) && !_useFingerprint) ...[
                  const SizedBox(height: 8),
                  for (var row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', '⌫']])
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: row.map((val) {
                        if (val.isEmpty) return const SizedBox(width: 64, height: 64);
                        return Container(
                          margin: const EdgeInsets.all(6),
                          width: 64,
                          height: 64,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
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
                            child: val == '⌫'
                                ? const Icon(Icons.backspace_outlined, size: 20, color: Colors.white70)
                                : Text(
                                    val,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.white,
                                    ),
                                  ),
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