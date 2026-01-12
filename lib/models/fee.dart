/// Payment status for fee tracking
enum PaymentStatus {
  pending,
  paid,
  overdue,
  partial;

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.overdue:
        return 'Overdue';
      case PaymentStatus.partial:
        return 'Partial';
    }
  }

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}

/// Fee/Payment model for tracking student payments
class Fee {
  final int? id;
  final int studentId;
  final int amount;
  final DateTime dueDate;
  final DateTime? paidDate;
  final PaymentStatus status;
  final String? notes;
  final String month; // "January 2026"
  final int? partialAmount; // Amount paid if partial

  Fee({
    this.id,
    required this.studentId,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    this.status = PaymentStatus.pending,
    this.notes,
    required this.month,
    this.partialAmount,
  });

  /// Check if fee is overdue
  bool get isOverdue =>
      status == PaymentStatus.pending && DateTime.now().isAfter(dueDate);

  /// Get remaining amount for partial payments
  int get remainingAmount => amount - (partialAmount ?? 0);

  /// Create a copy with modified fields
  Fee copyWith({
    int? id,
    int? studentId,
    int? amount,
    DateTime? dueDate,
    DateTime? paidDate,
    PaymentStatus? status,
    String? notes,
    String? month,
    int? partialAmount,
  }) {
    return Fee(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      month: month ?? this.month,
      partialAmount: partialAmount ?? this.partialAmount,
    );
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'paidDate': paidDate?.toIso8601String(),
      'status': status.name,
      'notes': notes,
      'month': month,
      'partialAmount': partialAmount,
    };
  }

  /// Create from database Map
  factory Fee.fromMap(Map<String, dynamic> map) {
    return Fee(
      id: map['id'] as int?,
      studentId: map['studentId'] as int,
      amount: map['amount'] as int,
      dueDate: DateTime.parse(map['dueDate'] as String),
      paidDate: map['paidDate'] != null
          ? DateTime.parse(map['paidDate'] as String)
          : null,
      status: PaymentStatus.fromString(map['status'] as String),
      notes: map['notes'] as String?,
      month: map['month'] as String,
      partialAmount: map['partialAmount'] as int?,
    );
  }

  // Legacy support - keeping old toJson/fromJson for compatibility
  Map<String, dynamic> toJson() => toMap();

  factory Fee.fromJson(Map<String, dynamic> json) => Fee.fromMap(json);

  @override
  String toString() {
    return 'Fee(id: $id, studentId: $studentId, amount: $amount, month: $month, status: ${status.name})';
  }
}
