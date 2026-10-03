import 'package:flutter/material.dart';

class CardConfig {
  final String id;
  final String title;
  final GlobalKey key;
  bool isVisible;
  bool isWide;

  CardConfig({
    required this.id,
    required this.title,
    required this.key,
    this.isVisible = true,
    this.isWide = false,
  });
}