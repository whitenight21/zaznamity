import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TitleCard extends StatefulWidget {
  final List<String> owners;
  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const TitleCard({
    super.key,
    required this.owners,
    required this.isWide,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<TitleCard> createState() => _TitleCardState();
}

class _TitleCardState extends State<TitleCard> {
  String _displayName = 'User';
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void didUpdateWidget(covariant TitleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Read card visibility preference linked with AppSettingsCard
    final visible = prefs.getBool('titleCardVisible') ?? true;

    // Read custom preferred name set in settings
    final savedCustomName = prefs.getString('titleCardCustomMessage') ?? prefs.getString('custom_display_name');
    
    if (mounted) {
      setState(() {
        _isVisible = visible;
        if (savedCustomName != null && savedCustomName.trim().isNotEmpty) {
          _displayName = savedCustomName.trim();
        } else if (widget.owners.isNotEmpty) {
          _displayName = widget.owners.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If visibility toggle in settings is turned off, hide the card completely
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    // Format current date with year e.g. "Oct 17, 2026"
    final currentDateFormatted = DateFormat('MMM d, yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        // Gradient: Dark purple at top fading down to solid black
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3B1E63), // Dark Purple
            Color(0xFF160D25), // Deep Dark Shade
            Color(0xFF000000), // Solid Black
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF582F95).withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top Row: Inline date with year aligned to the top right
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                currentDateFormatted,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white60,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Middle Row: Logo stack & Welcome text beside it
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo + Zaznamity title stacked vertically (Doubled size)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/ZaznamityLogoFULL.jpg',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ZAZNAMITY',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Beside the logo: Welcome message & Indented refined Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome,',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.8,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Bottom Subtitle: Centered alignment
          const Center(
            child: Text(
              'RECORD • TRACK • FOCUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9D65FF), // Accent Purple
                letterSpacing: 2.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}