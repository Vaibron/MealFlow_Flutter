class MealType {
  final int id;
  final String name;
  final String? description;
  final bool isActive;

  MealType({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
  });

  factory MealType.fromJson(Map<String, dynamic> json) {
    return MealType(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive,
    };
  }

  String get displayName {
    // Здесь можно добавить локализацию, пока просто возвращаем name
    return name;
  }
}
