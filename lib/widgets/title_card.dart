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
    
    final visible = prefs.getBool('titleCardVisible') ?? true;

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

    // CHANGED: Combined day of week and month/day on the top row, year on the bottom row
    final dayText = DateFormat('EEEE').format(DateTime.now());
    final monthAndYearText = DateFormat('MMM d, yyyy').format(DateTime.now());

    return Container(
      // Minimal top padding to place the date level with the profile picture top edge
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 10),
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
          // Main Row: Avatar with Profile Top Edge aligned with Date on the right
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
                                  width: 92.4,
                                  height: 92.4,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  'assets/ZaznamityLogoFULL.jpg',
                                  width: 92.4,
                                  height: 92.4,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
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
                  const SizedBox(height: 4),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date aligned precisely with the top edge of the avatar row
                    Padding( 
                      padding: const EdgeInsets.only(top: -25.0), // Adjust this value to move date up or down
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                dayText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                monthAndYearText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white60,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.translate(
                            offset: const Offset(-7.0, -3.0),
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
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
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
              ),
            ],
          ),
          const SizedBox(height: 10), 
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