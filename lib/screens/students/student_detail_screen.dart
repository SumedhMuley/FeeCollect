import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/student.dart';
import '../../models/batch.dart';
import '../../models/fee.dart';
import '../../services/reminder_service.dart';
import 'add_student_screen.dart';
import '../fees/collect_fee_screen.dart';

/// Screen showing detailed student information with payment history
class StudentDetailScreen extends StatefulWidget {
  final int studentId;
  
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> 
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper.instance;
  late TabController _tabController;
  
  Student? _student;
  Batch? _batch;
  List<Fee> _fees = [];
  Map<String, int> _attendanceStats = {
    'present': 0,
    'absent': 0,
    'late': 0,
    'total': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final student = await _db.getStudentById(widget.studentId);
      Batch? batch;
      if (student?.batchId != null) {
        batch = await _db.getBatchById(student!.batchId!);
      }
      final fees = await _db.getFeesByStudent(widget.studentId);
      final attendanceStats = await _db.getStudentAttendanceStats(widget.studentId);
      
      setState(() {
        _student = student;
        _batch = batch;
        _fees = fees;
        _attendanceStats = attendanceStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Details')),
        body: const Center(child: Text('Student not found')),
      );
    }
    
    final student = _student!;
    
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddStudentScreen(studentId: student.id),
                    ),
                  ).then((_) => _loadData()),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(student.name),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primaryContainer,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: theme.colorScheme.onPrimary,
                          child: Text(
                            student.name.isNotEmpty 
                                ? student.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Payments'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(student, theme),
            _buildPaymentsTab(theme),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CollectFeeScreen(studentId: student.id),
          ),
        ).then((_) => _loadData()),
        icon: const Icon(Icons.add),
        label: const Text('Add Fee'),
      ),
    );
  }

  Widget _buildOverviewTab(Student student, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Actions
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.call,
                  label: 'Call',
                  color: Colors.green,
                  onTap: () => ReminderService.makeCall(student.phone),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: Colors.teal,
                  onTap: () => _sendQuickWhatsApp(student),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.sms,
                  label: 'SMS',
                  color: Colors.blue,
                  onTap: () => _sendQuickSMS(student),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Contact Info Card
          _buildInfoCard(
            theme,
            title: 'Contact Information',
            icon: Icons.contact_phone,
            children: [
              _buildInfoRow('Phone', student.phone),
              if (student.email != null && student.email!.isNotEmpty)
                _buildInfoRow('Email', student.email!),
              if (student.guardianName != null && student.guardianName!.isNotEmpty)
                _buildInfoRow('Guardian', student.guardianName!),
              if (student.guardianPhone != null && student.guardianPhone!.isNotEmpty)
                _buildInfoRow('Guardian Phone', student.guardianPhone!),
            ],
          ),
          const SizedBox(height: 16),
          
          // Coaching Info Card
          _buildInfoCard(
            theme,
            title: 'Coaching Details',
            icon: Icons.sports,
            children: [
              if (student.sport != null) _buildInfoRow('Sport', student.sport!),
              if (_batch != null) ...[
                _buildInfoRow('Batch', _batch!.name),
                _buildInfoRow('Timing', _batch!.timing),
                _buildInfoRow('Days', _batch!.daysList.join(', ')),
              ],
              _buildInfoRow('Monthly Fee', '₹${student.monthlyFee}'),
              _buildInfoRow('Join Date', DateFormat('dd MMM yyyy').format(student.joinDate)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Attendance Summary Card
          _buildInfoCard(
            theme,
            title: 'Attendance Summary',
            icon: Icons.fact_check,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttendanceStat(
                    'Present',
                    _attendanceStats['present']!,
                    Colors.green,
                  ),
                  _buildAttendanceStat(
                    'Absent',
                    _attendanceStats['absent']!,
                    Colors.red,
                  ),
                  _buildAttendanceStat(
                    'Late',
                    _attendanceStats['late']!,
                    Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_attendanceStats['total']! > 0)
                LinearProgressIndicator(
                  value: _attendanceStats['present']! / _attendanceStats['total']!,
                  backgroundColor: Colors.red.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation(Colors.green),
                ),
            ],
          ),
          
          if (student.notes != null && student.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoCard(
              theme,
              title: 'Notes',
              icon: Icons.notes,
              children: [
                Text(student.notes!),
              ],
            ),
          ],
          
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildPaymentsTab(ThemeData theme) {
    if (_fees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No payment records',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fees.length + 1, // +1 for summary card
      itemBuilder: (context, index) {
        if (index == 0) {
          // Payment summary
          final totalDue = _fees.fold<int>(0, (sum, f) => sum + f.amount);
          final totalPaid = _fees
              .where((f) => f.status == PaymentStatus.paid)
              .fold<int>(0, (sum, f) => sum + f.amount);
          final pending = totalDue - totalPaid;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPaymentSummaryItem('Total', totalDue, theme.colorScheme.primary),
                      _buildPaymentSummaryItem('Paid', totalPaid, Colors.green),
                      _buildPaymentSummaryItem('Pending', pending, Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        
        final fee = _fees[index - 1];
        return _buildFeeCard(fee, theme);
      },
    );
  }

  Widget _buildFeeCard(Fee fee, ThemeData theme) {
    Color statusColor;
    IconData statusIcon;
    
    switch (fee.status) {
      case PaymentStatus.paid:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PaymentStatus.overdue:
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      case PaymentStatus.partial:
        statusColor = Colors.orange;
        statusIcon = Icons.timelapse;
        break;
      default:
        statusColor = fee.isOverdue ? Colors.red : Colors.orange;
        statusIcon = fee.isOverdue ? Icons.warning : Icons.schedule;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(fee.month),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Due: ${DateFormat('dd MMM yyyy').format(fee.dueDate)}'),
            if (fee.paidDate != null)
              Text(
                'Paid: ${DateFormat('dd MMM yyyy').format(fee.paidDate!)}',
                style: const TextStyle(color: Colors.green),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${fee.amount}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                fee.status.displayName,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: fee.status != PaymentStatus.paid
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CollectFeeScreen(
                    studentId: _student!.id,
                    feeId: fee.id,
                  ),
                ),
              ).then((_) => _loadData())
            : null,
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPaymentSummaryItem(String label, int amount, Color color) {
    return Column(
      children: [
        Text(
          '₹$amount',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Future<void> _sendQuickWhatsApp(Student student) async {
    final pendingFees = _fees.where((f) => 
        f.status == PaymentStatus.pending || f.status == PaymentStatus.overdue
    ).toList();
    
    if (pendingFees.isEmpty) {
      // Just send a greeting
      final phone = student.guardianPhone ?? student.phone;
      final message = 'Hi ${student.guardianName ?? student.name}, '
          'this is Blue Academy. How are you?';
      
      final uri = Uri.parse(
        'https://wa.me/${_formatPhone(phone)}?text=${Uri.encodeComponent(message)}'
      );
      
      await ReminderService.makeCall(phone); // This will open the dialer, change to launch WhatsApp
    } else {
      await ReminderService.sendWhatsAppReminder(
        student: student,
        fee: pendingFees.first,
      );
    }
  }

  Future<void> _sendQuickSMS(Student student) async {
    final pendingFees = _fees.where((f) => 
        f.status == PaymentStatus.pending || f.status == PaymentStatus.overdue
    ).toList();
    
    if (pendingFees.isNotEmpty) {
      await ReminderService.sendSMSReminder(
        student: student,
        fee: pendingFees.first,
      );
    }
  }

  String _formatPhone(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleanPhone.startsWith('+')) {
      if (cleanPhone.startsWith('0')) {
        cleanPhone = cleanPhone.substring(1);
      }
      cleanPhone = '91$cleanPhone';
    }
    return cleanPhone;
  }
}
