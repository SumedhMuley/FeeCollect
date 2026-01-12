import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/student.dart';
import '../../models/batch.dart';
import '../../models/attendance.dart';

/// Screen for marking daily attendance
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  DateTime _selectedDate = DateTime.now();
  List<Batch> _batches = [];
  int? _selectedBatchId;
  List<Student> _students = [];
  Map<int, AttendanceStatus> _attendanceMap = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final batches = await _db.getAllBatches(activeOnly: true);
      
      List<Student> students;
      if (_selectedBatchId != null) {
        students = await _db.getStudentsByBatch(_selectedBatchId!);
      } else {
        students = await _db.getAllStudents(activeOnly: true);
      }
      
      // Load existing attendance for selected date
      final existingAttendance = await _db.getAttendanceByDate(_selectedDate);
      final Map<int, AttendanceStatus> attendanceMap = {};
      
      for (final record in existingAttendance) {
        attendanceMap[record.studentId] = record.status;
      }
      
      setState(() {
        _batches = batches;
        _students = students;
        _attendanceMap = attendanceMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  Future<void> _saveAttendance() async {
    if (_attendanceMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please mark attendance for at least one student')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      for (final entry in _attendanceMap.entries) {
        final attendance = Attendance(
          studentId: entry.key,
          date: _selectedDate,
          status: entry.value,
        );
        await _db.upsertAttendance(attendance);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving attendance: $e')),
        );
      }
    }
    
    setState(() => _isSaving = false);
  }

  void _setStatus(int studentId, AttendanceStatus status) {
    setState(() {
      _attendanceMap[studentId] = status;
    });
  }

  void _markAllPresent() {
    setState(() {
      for (final student in _students) {
        if (student.id != null) {
          _attendanceMap[student.id!] = AttendanceStatus.present;
        }
      }
    });
  }

  void _markAllAbsent() {
    setState(() {
      for (final student in _students) {
        if (student.id != null) {
          _attendanceMap[student.id!] = AttendanceStatus.absent;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    
    final presentCount = _attendanceMap.values
        .where((s) => s == AttendanceStatus.present)
        .length;
    final absentCount = _attendanceMap.values
        .where((s) => s == AttendanceStatus.absent)
        .length;
    final lateCount = _attendanceMap.values
        .where((s) => s == AttendanceStatus.late)
        .length;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () => _showAttendanceHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(
                        const Duration(days: 1),
                      );
                    });
                    _loadData();
                  },
                ),
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isToday
                                ? 'Today, ${DateFormat('dd MMM').format(_selectedDate)}'
                                : DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _selectedDate.isBefore(DateTime.now())
                      ? () {
                          setState(() {
                            _selectedDate = _selectedDate.add(
                              const Duration(days: 1),
                            );
                          });
                          _loadData();
                        }
                      : null,
                ),
              ],
            ),
          ),
          
          // Batch filter
          if (_batches.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All Students'),
                    selected: _selectedBatchId == null,
                    onSelected: (selected) {
                      setState(() => _selectedBatchId = null);
                      _loadData();
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._batches.map((batch) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(batch.name),
                      selected: _selectedBatchId == batch.id,
                      onSelected: (selected) {
                        setState(() => _selectedBatchId = selected ? batch.id : null);
                        _loadData();
                      },
                    ),
                  )),
                ],
              ),
            ),
          
          // Quick actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_students.length} students',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _markAllPresent,
                  icon: const Icon(Icons.check_circle, size: 18, color: Colors.green),
                  label: const Text('All Present'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
                TextButton.icon(
                  onPressed: _markAllAbsent,
                  icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                  label: const Text('All Absent'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ),
          
          // Summary bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryChip('Present', presentCount, Colors.green),
                _buildSummaryChip('Absent', absentCount, Colors.red),
                _buildSummaryChip('Late', lateCount, Colors.orange),
              ],
            ),
          ),
          
          // Student list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          return _buildStudentAttendanceCard(
                            _students[index],
                            theme,
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _students.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveAttendance,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Attendance'),
              ),
            )
          : null,
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $count',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No students found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedBatchId != null
                ? 'No students in this batch'
                : 'Add students to mark attendance',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAttendanceCard(Student student, ThemeData theme) {
    final status = _attendanceMap[student.id];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getStatusColor(status).withOpacity(0.2),
              child: Text(
                student.name[0].toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (student.sport != null)
                    Text(
                      student.sport!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            // Status buttons
            ToggleButtons(
              isSelected: [
                status == AttendanceStatus.present,
                status == AttendanceStatus.absent,
                status == AttendanceStatus.late,
              ],
              onPressed: (index) {
                final newStatus = [
                  AttendanceStatus.present,
                  AttendanceStatus.absent,
                  AttendanceStatus.late,
                ][index];
                _setStatus(student.id!, newStatus);
              },
              borderRadius: BorderRadius.circular(8),
              selectedBorderColor: _getStatusColor(status),
              fillColor: _getStatusColor(status).withOpacity(0.2),
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 36,
              ),
              children: const [
                Tooltip(
                  message: 'Present',
                  child: Icon(Icons.check, color: Colors.green, size: 20),
                ),
                Tooltip(
                  message: 'Absent',
                  child: Icon(Icons.close, color: Colors.red, size: 20),
                ),
                Tooltip(
                  message: 'Late',
                  child: Icon(Icons.schedule, color: Colors.orange, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus? status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.late:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showAttendanceHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => AttendanceHistorySheet(
          scrollController: scrollController,
        ),
      ),
    );
  }
}

/// Bottom sheet for viewing attendance history
class AttendanceHistorySheet extends StatefulWidget {
  final ScrollController scrollController;
  
  const AttendanceHistorySheet({super.key, required this.scrollController});

  @override
  State<AttendanceHistorySheet> createState() => _AttendanceHistorySheetState();
}

class _AttendanceHistorySheetState extends State<AttendanceHistorySheet> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final List<Map<String, dynamic>> items = [];
      
      // Get last 30 days of attendance
      for (int i = 0; i < 30; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final attendance = await _db.getAttendanceByDate(date);
        
        if (attendance.isNotEmpty) {
          final present = attendance.where((a) => a.status == AttendanceStatus.present).length;
          final absent = attendance.where((a) => a.status == AttendanceStatus.absent).length;
          final late = attendance.where((a) => a.status == AttendanceStatus.late).length;
          
          items.add({
            'date': date,
            'total': attendance.length,
            'present': present,
            'absent': absent,
            'late': late,
          });
        }
      }
      
      setState(() {
        _historyItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Attendance History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _historyItems.isEmpty
                  ? const Center(
                      child: Text('No attendance records yet'),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      itemCount: _historyItems.length,
                      itemBuilder: (context, index) {
                        final item = _historyItems[index];
                        final date = item['date'] as DateTime;
                        
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                            child: Text(
                              DateFormat('dd').format(date),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(DateFormat('EEEE, dd MMM yyyy').format(date)),
                          subtitle: Row(
                            children: [
                              _buildMiniStat('P', item['present'], Colors.green),
                              const SizedBox(width: 12),
                              _buildMiniStat('A', item['absent'], Colors.red),
                              const SizedBox(width: 12),
                              _buildMiniStat('L', item['late'], Colors.orange),
                            ],
                          ),
                          trailing: Text(
                            '${item['total']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label:$count',
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}
