// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TitleCard extends StatefulWidget {
  final List<String> owners;
  final String? selectedOwner;
  final bool isWide;
  final VoidCallback? onToggleWidth;
  final VoidCallback? onHide;

  const TitleCard({
    super.key,
    required this.owners,
    this.selectedOwner,
    required this.isWide,
    this.onToggleWidth,
    this.onHide,
  });

  @override
  State<TitleCard> createState() => _TitleCardState();
}

class _TitleCardState extends State<TitleCard> {
  String _displayName = 'User';
  String? _avatarPath;
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

    // Prioritize widget.selectedOwner passed from DashboardScreen
    String activeOwner = 'User';
    if (widget.selectedOwner != null && widget.owners.contains(widget.selectedOwner)) {
      activeOwner = widget.selectedOwner!;
    } else {
      final savedGlobalOwner = prefs.getString('master_owner') ?? prefs.getString('globalSelectedOwner');
      if (savedGlobalOwner != null && widget.owners.contains(savedGlobalOwner)) {
        activeOwner = savedGlobalOwner;
      } else if (widget.owners.isNotEmpty) {
        activeOwner = widget.owners.first;
      }
    }

    final avatarPath = prefs.getString('owner_avatar_path_$activeOwner');
    
    if (mounted) {
      setState(() {
        _isVisible = visible;
        _displayName = activeOwner;
        _avatarPath = avatarPath;
      });
    }
  }

  Future<void> _pickProfilePicture() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Images',
        extensions: <String>['jpg', 'jpeg', 'png'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'avatar_${_displayName}_${DateTime.now().millisecondsSinceEpoch}.${file.path.split('.').last}';
      final savedImage = File('${appDir.path}/$fileName');
      await File(file.path).copy(savedImage.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('owner_avatar_path_$_displayName', savedImage.path);

      setState(() {
        _avatarPath = savedImage.path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile picture updated for $_displayName!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile picture: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    // Format day of week e.g. "Tuesday," and date e.g. "Oct 20, 2026"[cite: 5]
    final currentDayOfWeek = DateFormat('EEEE,').format(DateTime.now());
    final currentDateFormatted = DateFormat('MMM d, yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3B1E63),
            Color(0xFF160D25),
            Color(0xFF000000),
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
          // Middle Row: Profile Picture Avatar with Zaznamity Logo Badge & Owner Name, with Day/Date perfectly aligned with the top edge of the avatar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: _pickProfilePicture,
                        child: ClipOval(
                          child: _avatarPath != null && File(_avatarPath!).existsSync()
                              ? Image.file(
                                  File(_avatarPath!),
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  'assets/ZaznamityLogoFULL.jpg',
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      // Zaznamity Logo Badge in bottom right corner
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D1B4E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/ZaznamityLogoFULL.jpg',
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(-7.0, 0.0),
                        child: const Text(
                          'Welcome,',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                            letterSpacing: 0.3,
                          ),
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
              ),
              // Top Right: Day of week and Date perfectly inline with the top edge of the profile picture
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currentDayOfWeek,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentDateFormatted,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white60,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'RECORD • TRACK • FOCUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9D65FF),
                letterSpacing: 2.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}