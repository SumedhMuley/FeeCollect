/// Student model for Blue Academy coaching management
class Student {
  final int? id;
  final String name;
  final String phone;
  final String? email;
  final String? guardianName;
  final String? guardianPhone;
  final int? batchId;
  final int monthlyFee;
  final DateTime joinDate;
  final bool isActive;
  final String? sport; // Swimming, Cricket, etc.
  final String? notes;

  Student({
    this.id,
    required this.name,
    required this.phone,
    this.email,
    this.guardianName,
    this.guardianPhone,
    this.batchId,
    required this.monthlyFee,
    required this.joinDate,
    this.isActive = true,
    this.sport,
    this.notes,
  });

  /// Create a copy with modified fields
  Student copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? guardianName,
    String? guardianPhone,
    int? batchId,
    int? monthlyFee,
    DateTime? joinDate,
    bool? isActive,
    String? sport,
    String? notes,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      batchId: batchId ?? this.batchId,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      joinDate: joinDate ?? this.joinDate,
      isActive: isActive ?? this.isActive,
      sport: sport ?? this.sport,
      notes: notes ?? this.notes,
    );
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'guardianName': guardianName,
      'guardianPhone': guardianPhone,
      'batchId': batchId,
      'monthlyFee': monthlyFee,
      'joinDate': joinDate.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'sport': sport,
      'notes': notes,
    };
  }

  /// Create from database Map
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      guardianName: map['guardianName'] as String?,
      guardianPhone: map['guardianPhone'] as String?,
      batchId: map['batchId'] as int?,
      monthlyFee: map['monthlyFee'] as int,
      joinDate: DateTime.parse(map['joinDate'] as String),
      isActive: (map['isActive'] as int) == 1,
      sport: map['sport'] as String?,
      notes: map['notes'] as String?,
    );
  }

  @override
  String toString() {
    return 'Student(id: $id, name: $name, phone: $phone, sport: $sport)';
  }
}
