/// Batch/Group model for organizing students
class Batch {
  final int? id;
  final String name;
  final String? description;
  final String timing;
  final String days; // Stored as comma-separated: "Mon,Wed,Fri"
  final String? sport;
  final bool isActive;

  Batch({
    this.id,
    required this.name,
    this.description,
    required this.timing,
    required this.days,
    this.sport,
    this.isActive = true,
  });

  /// Get days as a list
  List<String> get daysList => days.split(',').map((e) => e.trim()).toList();

  /// Create a copy with modified fields
  Batch copyWith({
    int? id,
    String? name,
    String? description,
    String? timing,
    String? days,
    String? sport,
    bool? isActive,
  }) {
    return Batch(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      timing: timing ?? this.timing,
      days: days ?? this.days,
      sport: sport ?? this.sport,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'timing': timing,
      'days': days,
      'sport': sport,
      'isActive': isActive ? 1 : 0,
    };
  }

  /// Create from database Map
  factory Batch.fromMap(Map<String, dynamic> map) {
    return Batch(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      timing: map['timing'] as String,
      days: map['days'] as String,
      sport: map['sport'] as String?,
      isActive: (map['isActive'] as int) == 1,
    );
  }

  @override
  String toString() {
    return 'Batch(id: $id, name: $name, timing: $timing, days: $days)';
  }
}
