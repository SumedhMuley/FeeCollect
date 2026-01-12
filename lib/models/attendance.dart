/// Attendance status options
enum AttendanceStatus {
  present,
  absent,
  late;

  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
    }
  }

  static AttendanceStatus fromString(String value) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AttendanceStatus.absent,
    );
  }
}

/// Attendance record model
class Attendance {
  final int? id;
  final int studentId;
  final DateTime date;
  final AttendanceStatus status;
  final String? notes;

  Attendance({
    this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.notes,
  });

  /// Create a copy with modified fields
  Attendance copyWith({
    int? id,
    int? studentId,
    DateTime? date,
    AttendanceStatus? status,
    String? notes,
  }) {
    return Attendance(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'date': date.toIso8601String().split('T')[0], // Store only date part
      'status': status.name,
      'notes': notes,
    };
  }

  /// Create from database Map
  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as int?,
      studentId: map['studentId'] as int,
      date: DateTime.parse(map['date'] as String),
      status: AttendanceStatus.fromString(map['status'] as String),
      notes: map['notes'] as String?,
    );
  }

  @override
  String toString() {
    return 'Attendance(id: $id, studentId: $studentId, date: ${date.toIso8601String().split('T')[0]}, status: ${status.name})';
  }
}
