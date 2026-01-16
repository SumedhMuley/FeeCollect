import 'package:sqflite/sqflite.dart' hide Batch;
import 'package:path/path.dart';
import '../models/student.dart';
import '../models/batch.dart';
import '../models/fee.dart';
import '../models/attendance.dart';

/// Database helper for Blue Academy fee collection app
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get database instance (creates if not exists)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('blue_academy.db');
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  /// Create all database tables
  Future<void> _createDB(Database db, int version) async {
    // Batches table
    await db.execute('''
      CREATE TABLE batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        timing TEXT NOT NULL,
        days TEXT NOT NULL,
        sport TEXT,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Students table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        guardianName TEXT,
        guardianPhone TEXT,
        batchId INTEGER,
        monthlyFee INTEGER NOT NULL,
        joinDate TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        sport TEXT,
        notes TEXT,
        hasGym INTEGER NOT NULL DEFAULT 0,
        hasDiet INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (batchId) REFERENCES batches (id) ON DELETE SET NULL
      )
    ''');

    // Fees table
    await db.execute('''
      CREATE TABLE fees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        dueDate TEXT NOT NULL,
        paidDate TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        notes TEXT,
        month TEXT NOT NULL,
        partialAmount INTEGER,
        FOREIGN KEY (studentId) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // Attendance table
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (studentId) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better query performance
    await db.execute(
        'CREATE INDEX idx_students_batch ON students (batchId)');
    await db.execute(
        'CREATE INDEX idx_fees_student ON fees (studentId)');
    await db.execute(
        'CREATE INDEX idx_fees_status ON fees (status)');
    await db.execute(
        'CREATE INDEX idx_attendance_student ON attendance (studentId)');
    await db.execute(
        'CREATE INDEX idx_attendance_date ON attendance (date)');
  }

  // ==================== BATCH OPERATIONS ====================

  /// Insert a new batch
  Future<int> insertBatch(Batch batch) async {
    final db = await database;
    return await db.insert('batches', batch.toMap()..remove('id'));
  }

  /// Get all batches
  Future<List<Batch>> getAllBatches({bool activeOnly = false}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'batches',
      where: activeOnly ? 'isActive = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name ASC',
    );
    return List<Batch>.from(maps.map((map) => Batch.fromMap(map)));
  }

  /// Get batch by ID
  Future<Batch?> getBatchById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'batches',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Batch.fromMap(maps.first);
  }

  /// Update a batch
  Future<int> updateBatch(Batch batch) async {
    final db = await database;
    return await db.update(
      'batches',
      batch.toMap(),
      where: 'id = ?',
      whereArgs: [batch.id],
    );
  }

  /// Delete a batch
  Future<int> deleteBatch(int id) async {
    final db = await database;
    return await db.delete('batches', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== STUDENT OPERATIONS ====================

  /// Insert a new student
  Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert('students', student.toMap()..remove('id'));
  }

  /// Get all students
  Future<List<Student>> getAllStudents({
    bool activeOnly = false,
    int? batchId,
  }) async {
    final db = await database;
    
    String? where;
    List<dynamic>? whereArgs;
    
    if (activeOnly && batchId != null) {
      where = 'isActive = ? AND batchId = ?';
      whereArgs = [1, batchId];
    } else if (activeOnly) {
      where = 'isActive = ?';
      whereArgs = [1];
    } else if (batchId != null) {
      where = 'batchId = ?';
      whereArgs = [batchId];
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return List<Student>.from(maps.map((map) => Student.fromMap(map)));
  }

  /// Get student by ID
  Future<Student?> getStudentById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Student.fromMap(maps.first);
  }

  /// Search students by name
  Future<List<Student>> searchStudents(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return List<Student>.from(maps.map((map) => Student.fromMap(map)));
  }

  /// Update a student
  Future<int> updateStudent(Student student) async {
    final db = await database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  /// Delete a student
  Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  /// Get student count
  Future<int> getStudentCount({bool activeOnly = true}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM students ${activeOnly ? "WHERE isActive = 1" : ""}',
    );
    return result.first['count'] as int;
  }

  /// Get students by batch
  Future<List<Student>> getStudentsByBatch(int batchId) async {
    return getAllStudents(batchId: batchId, activeOnly: true);
  }

  // ==================== FEE OPERATIONS ====================

  /// Insert a new fee
  Future<int> insertFee(Fee fee) async {
    final db = await database;
    return await db.insert('fees', fee.toMap()..remove('id'));
  }

  /// Get all fees for a student
  Future<List<Fee>> getFeesByStudent(int studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fees',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'dueDate DESC',
    );
    return List<Fee>.from(maps.map((map) => Fee.fromMap(map)));
  }

  /// Get all pending fees
  Future<List<Fee>> getPendingFees() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fees',
      where: 'status = ? OR status = ?',
      whereArgs: ['pending', 'overdue'],
      orderBy: 'dueDate ASC',
    );
    return List<Fee>.from(maps.map((map) => Fee.fromMap(map)));
  }

  /// Get overdue fees
  Future<List<Fee>> getOverdueFees() async {
    final db = await database;
    final now = DateTime.now().toIso8601String().split('T')[0];
    final List<Map<String, dynamic>> maps = await db.query(
      'fees',
      where: '(status = ? OR status = ?) AND dueDate < ?',
      whereArgs: ['pending', 'overdue', now],
      orderBy: 'dueDate ASC',
    );
    return List<Fee>.from(maps.map((map) => Fee.fromMap(map)));
  }

  /// Get fees for a specific month
  Future<List<Fee>> getFeesByMonth(String month) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fees',
      where: 'month = ?',
      whereArgs: [month],
      orderBy: 'dueDate ASC',
    );
    return List<Fee>.from(maps.map((map) => Fee.fromMap(map)));
  }

  /// Update a fee
  Future<int> updateFee(Fee fee) async {
    final db = await database;
    return await db.update(
      'fees',
      fee.toMap(),
      where: 'id = ?',
      whereArgs: [fee.id],
    );
  }

  /// Mark fee as paid
  Future<int> markFeePaid(int feeId, {DateTime? paidDate}) async {
    final db = await database;
    return await db.update(
      'fees',
      {
        'status': PaymentStatus.paid.name,
        'paidDate': (paidDate ?? DateTime.now()).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [feeId],
    );
  }

  /// Delete a fee
  Future<int> deleteFee(int id) async {
    final db = await database;
    return await db.delete('fees', where: 'id = ?', whereArgs: [id]);
  }

  /// Get total collection for current month
  Future<int> getMonthlyCollection(String month) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM fees WHERE month = ? AND status = ?',
      [month, 'paid'],
    );
    return result.first['total'] as int;
  }

  /// Get pending amount for current month
  Future<int> getPendingAmount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM fees WHERE status = ? OR status = ?',
      ['pending', 'overdue'],
    );
    return result.first['total'] as int;
  }

  /// Get pending fee count
  Future<int> getPendingFeeCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM fees WHERE status = ? OR status = ?',
      ['pending', 'overdue'],
    );
    return result.first['count'] as int;
  }

  // ==================== ATTENDANCE OPERATIONS ====================

  /// Insert attendance record
  Future<int> insertAttendance(Attendance attendance) async {
    final db = await database;
    return await db.insert('attendance', attendance.toMap()..remove('id'));
  }

  /// Insert or update attendance for a student on a date
  Future<void> upsertAttendance(Attendance attendance) async {
    final db = await database;
    final dateStr = attendance.date.toIso8601String().split('T')[0];
    
    final existing = await db.query(
      'attendance',
      where: 'studentId = ? AND date = ?',
      whereArgs: [attendance.studentId, dateStr],
    );
    
    if (existing.isEmpty) {
      await db.insert('attendance', attendance.toMap()..remove('id'));
    } else {
      await db.update(
        'attendance',
        attendance.toMap()..remove('id'),
        where: 'studentId = ? AND date = ?',
        whereArgs: [attendance.studentId, dateStr],
      );
    }
  }

  /// Get attendance for a specific date
  Future<List<Attendance>> getAttendanceByDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [dateStr],
    );
    return List<Attendance>.from(maps.map((map) => Attendance.fromMap(map)));
  }

  /// Get attendance for a student
  Future<List<Attendance>> getAttendanceByStudent(int studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
    return List<Attendance>.from(maps.map((map) => Attendance.fromMap(map)));
  }

  /// Get attendance stats for a student
  Future<Map<String, int>> getStudentAttendanceStats(int studentId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present,
        SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent,
        SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as late,
        COUNT(*) as total
      FROM attendance 
      WHERE studentId = ?
    ''', [studentId]);
    
    final row = result.first;
    return {
      'present': (row['present'] as int?) ?? 0,
      'absent': (row['absent'] as int?) ?? 0,
      'late': (row['late'] as int?) ?? 0,
      'total': (row['total'] as int?) ?? 0,
    };
  }

  /// Get today's attendance summary
  Future<Map<String, int>> getTodayAttendanceSummary() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];
    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN status = 'present' THEN 1 ELSE 0 END) as present,
        SUM(CASE WHEN status = 'absent' THEN 1 ELSE 0 END) as absent,
        SUM(CASE WHEN status = 'late' THEN 1 ELSE 0 END) as late
      FROM attendance 
      WHERE date = ?
    ''', [today]);
    
    final row = result.first;
    return {
      'present': (row['present'] as int?) ?? 0,
      'absent': (row['absent'] as int?) ?? 0,
      'late': (row['late'] as int?) ?? 0,
    };
  }

  /// Delete attendance record
  Future<int> deleteAttendance(int id) async {
    final db = await database;
    return await db.delete('attendance', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== UTILITY OPERATIONS ====================

  /// Close the database
  Future<void> close() async {
    final db = await database;
    db.close();
  }

  /// Clear all data (for testing/reset)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('attendance');
    await db.delete('fees');
    await db.delete('students');
    await db.delete('batches');
  }
}
