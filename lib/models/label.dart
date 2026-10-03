class LabelModel {
  final int id;
  final String name;
  final String color;

  LabelModel({required this.id, required this.name, required this.color});

  factory LabelModel.fromMap(Map<String, dynamic> map) {
    return LabelModel(
      id: map['id'],
      name: map['name'],
      color: map['color'] ?? '#3b82f6',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }
}