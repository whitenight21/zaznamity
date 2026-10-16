import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  @override
  void didUpdateWidget(covariant TitleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    // Allows retrieving a custom preferred name set in settings if stored, otherwise defaults to the first owner
    final savedCustomName = prefs.getString('custom_display_name');
    if (savedCustomName != null && savedCustomName.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _displayName = savedCustomName.trim();
        });
      }
    } else if (widget.owners.isNotEmpty) {
      if (mounted) {
        setState(() {
          _displayName = widget.owners.first;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF582F95), // Purple background color
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Logo + "Zaznamity" stacked vertically
          Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/ZaznamityLogoFULL.jpg',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Zaznamity',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Beside: Welcome message with white text
              Text(
                'Welcome, $_displayName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}