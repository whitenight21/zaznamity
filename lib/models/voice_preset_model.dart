import 'dart:convert';

class VoicePreset {
  final String triggerWord; // e.g., "fresh"
  final String description; // e.g., "Fresh"
  final String label;       // e.g., "Food"
  final String type;        // e.g., "expense"
  final String pool;        // e.g., "checking"

  VoicePreset({
    required this.triggerWord,
    required this.description,
    required this.label,
    required this.type,
    required this.pool,
  });

  Map<String, dynamic> toJson() => {
        'triggerWord': triggerWord,
        'description': description,
        'label': label,
        'type': type,
        'pool': pool,
      };

  factory VoicePreset.fromJson(Map<String, dynamic> json) => VoicePreset(
        triggerWord: json['triggerWord'] ?? '',
        description: json['description'] ?? '',
        label: json['label'] ?? '',
        type: json['type'] ?? 'expense',
        pool: json['pool'] ?? 'checking',
      );
}