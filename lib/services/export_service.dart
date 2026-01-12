import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/fee.dart';
import '../database/database_helper.dart';

/// Service for exporting data to CSV files
class ExportService {
  static final DatabaseHelper _db = DatabaseHelper.instance;

  /// Export all students to CSV
  static Future<String> exportStudentsToCSV() async {
    final students = await _db.getAllStudents();
    final batches = await _db.getAllBatches();
    
    // Create batch name lookup
    final batchNames = <int, String>{};
    for (final batch in batches) {
      if (batch.id != null) {
        batchNames[batch.id!] = batch.name;
      }
    }
    
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('ID,Name,Phone,Email,Guardian Name,Guardian Phone,Batch,Monthly Fee,Join Date,Sport,Status');
    
    // Data rows
    for (final student in students) {
      final batchName = student.batchId != null ? batchNames[student.batchId] ?? '' : '';
      final joinDate = DateFormat('dd-MM-yyyy').format(student.joinDate);
      
      buffer.writeln(
        '${student.id},'
        '"${_escapeCSV(student.name)}",'
        '"${student.phone}",'
        '"${student.email ?? ''}",'
        '"${_escapeCSV(student.guardianName ?? '')}",'
        '"${student.guardianPhone ?? ''}",'
        '"${_escapeCSV(batchName)}",'
        '${student.monthlyFee},'
        '$joinDate,'
        '"${student.sport ?? ''}",'
        '${student.isActive ? "Active" : "Inactive"}'
      );
    }
    
    return buffer.toString();
  }

  /// Export fees/payments to CSV
  static Future<String> exportFeesToCSV({String? month}) async {
    final fees = month != null 
        ? await _db.getFeesByMonth(month)
        : await _db.getPendingFees();
    
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('ID,Student ID,Student Name,Amount,Month,Due Date,Paid Date,Status,Notes');
    
    // Get student names
    final students = await _db.getAllStudents();
    final studentNames = <int, String>{};
    for (final student in students) {
      if (student.id != null) {
        studentNames[student.id!] = student.name;
      }
    }
    
    // Data rows
    for (final fee in fees) {
      final studentName = studentNames[fee.studentId] ?? 'Unknown';
      final dueDate = DateFormat('dd-MM-yyyy').format(fee.dueDate);
      final paidDate = fee.paidDate != null 
          ? DateFormat('dd-MM-yyyy').format(fee.paidDate!)
          : '';
      
      buffer.writeln(
        '${fee.id},'
        '${fee.studentId},'
        '"${_escapeCSV(studentName)}",'
        '${fee.amount},'
        '"${fee.month}",'
        '$dueDate,'
        '$paidDate,'
        '${fee.status.displayName},'
        '"${_escapeCSV(fee.notes ?? '')}"'
      );
    }
    
    return buffer.toString();
  }

  /// Export attendance to CSV for a date range
  static Future<String> exportAttendanceToCSV({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final students = await _db.getAllStudents(activeOnly: true);
    final buffer = StringBuffer();
    
    // Header - dates as columns
    final headers = <String>['Student ID', 'Student Name'];
    for (var date = startDate; 
         date.isBefore(endDate.add(const Duration(days: 1))); 
         date = date.add(const Duration(days: 1))) {
      headers.add(DateFormat('dd-MM').format(date));
    }
    buffer.writeln(headers.join(','));
    
    // Data rows
    for (final student in students) {
      final attendanceRecords = await _db.getAttendanceByStudent(student.id!);
      final attendanceMap = <String, String>{};
      for (final record in attendanceRecords) {
        final dateKey = DateFormat('dd-MM').format(record.date);
        attendanceMap[dateKey] = record.status.name[0].toUpperCase(); // P, A, L
      }
      
      final row = <String>[
        '${student.id}',
        '"${_escapeCSV(student.name)}"',
      ];
      
      for (var date = startDate; 
           date.isBefore(endDate.add(const Duration(days: 1))); 
           date = date.add(const Duration(days: 1))) {
        final dateKey = DateFormat('dd-MM').format(date);
        row.add(attendanceMap[dateKey] ?? '-');
      }
      
      buffer.writeln(row.join(','));
    }
    
    return buffer.toString();
  }

  /// Export monthly report to CSV
  static Future<String> exportMonthlyReportToCSV(String month) async {
    final fees = await _db.getFeesByMonth(month);
    final students = await _db.getAllStudents();
    
    // Create student lookup
    final studentMap = <int, Student>{};
    for (final student in students) {
      if (student.id != null) {
        studentMap[student.id!] = student;
      }
    }
    
    final buffer = StringBuffer();
    
    // Summary section
    final totalAmount = fees.fold<int>(0, (sum, fee) => sum + fee.amount);
    final paidAmount = fees
        .where((f) => f.status == PaymentStatus.paid)
        .fold<int>(0, (sum, fee) => sum + fee.amount);
    final pendingAmount = totalAmount - paidAmount;
    final paidCount = fees.where((f) => f.status == PaymentStatus.paid).length;
    final pendingCount = fees.length - paidCount;
    
    buffer.writeln('Monthly Report: $month');
    buffer.writeln('');
    buffer.writeln('Summary');
    buffer.writeln('Total Expected,₹$totalAmount');
    buffer.writeln('Total Collected,₹$paidAmount');
    buffer.writeln('Total Pending,₹$pendingAmount');
    buffer.writeln('Paid Count,$paidCount');
    buffer.writeln('Pending Count,$pendingCount');
    buffer.writeln('');
    buffer.writeln('Details');
    buffer.writeln('Student Name,Phone,Amount,Status,Paid Date');
    
    for (final fee in fees) {
      final student = studentMap[fee.studentId];
      final studentName = student?.name ?? 'Unknown';
      final phone = student?.phone ?? '';
      final paidDate = fee.paidDate != null 
          ? DateFormat('dd-MM-yyyy').format(fee.paidDate!)
          : '';
      
      buffer.writeln(
        '"${_escapeCSV(studentName)}",'
        '"$phone",'
        '${fee.amount},'
        '${fee.status.displayName},'
        '$paidDate'
      );
    }
    
    return buffer.toString();
  }

  /// Save CSV content to file and share
  static Future<void> saveAndShareCSV(String content, String filename) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(content);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: filename,
    );
  }

  /// Escape CSV special characters
  static String _escapeCSV(String value) {
    return value.replaceAll('"', '""');
  }
}
