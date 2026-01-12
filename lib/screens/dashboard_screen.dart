import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/student.dart';
import '../models/fee.dart';
import 'students/add_student_screen.dart';
import 'fees/pending_fees_screen.dart';
import 'fees/collect_fee_screen.dart';
import 'batches/batches_screen.dart';

/// Dashboard screen showing overview and quick actions
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  int _totalStudents = 0;
  int _monthlyCollection = 0;
  int _pendingAmount = 0;
  int _pendingCount = 0;
  Map<String, int> _todayAttendance = {'present': 0, 'absent': 0, 'late': 0};
  List<Map<String, dynamic>> _recentPending = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
      
      final results = await Future.wait([
        _db.getStudentCount(activeOnly: true),
        _db.getMonthlyCollection(currentMonth),
        _db.getPendingAmount(),
        _db.getPendingFeeCount(),
        _db.getTodayAttendanceSummary(),
        _loadRecentPending(),
      ]);
      
      setState(() {
        _totalStudents = results[0] as int;
        _monthlyCollection = results[1] as int;
        _pendingAmount = results[2] as int;
        _pendingCount = results[3] as int;
        _todayAttendance = results[4] as Map<String, int>;
        _recentPending = results[5] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentPending() async {
    final pendingFees = await _db.getPendingFees();
    final List<Map<String, dynamic>> result = [];
    
    for (final fee in pendingFees.take(5)) {
      final student = await _db.getStudentById(fee.studentId);
      if (student != null) {
        result.add({'student': student, 'fee': fee});
      }
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pool, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Blue Academy'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome message
                    Text(
                      'Welcome back! 👋',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      currentMonth,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Stats cards
                    _buildStatsGrid(theme),
                    const SizedBox(height: 24),
                    
                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActions(context, theme),
                    const SizedBox(height: 24),
                    
                    // Pending Fees
                    if (_recentPending.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pending Payments',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PendingFeesScreen(),
                              ),
                            ).then((_) => _loadDashboardData()),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildPendingList(theme),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          theme,
          icon: Icons.people,
          label: 'Total Students',
          value: '$_totalStudents',
          color: theme.colorScheme.primary,
        ),
        _buildStatCard(
          theme,
          icon: Icons.account_balance_wallet,
          label: 'This Month',
          value: '₹$_monthlyCollection',
          color: Colors.green,
        ),
        _buildStatCard(
          theme,
          icon: Icons.pending_actions,
          label: 'Pending',
          value: '₹$_pendingAmount',
          subtitle: '$_pendingCount students',
          color: Colors.orange,
        ),
        _buildStatCard(
          theme,
          icon: Icons.fact_check,
          label: 'Today\'s Attendance',
          value: '${_todayAttendance['present'] ?? 0}P',
          subtitle: '${_todayAttendance['absent'] ?? 0}A / ${_todayAttendance['late'] ?? 0}L',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    required Color color,
  }) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildActionChip(
          context,
          icon: Icons.person_add,
          label: 'Add Student',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddStudentScreen()),
          ).then((_) => _loadDashboardData()),
        ),
        _buildActionChip(
          context,
          icon: Icons.payment,
          label: 'Collect Fee',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CollectFeeScreen()),
          ).then((_) => _loadDashboardData()),
        ),
        _buildActionChip(
          context,
          icon: Icons.groups,
          label: 'Batches',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BatchesScreen()),
          ).then((_) => _loadDashboardData()),
        ),
        _buildActionChip(
          context,
          icon: Icons.notifications,
          label: 'Send Reminders',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PendingFeesScreen()),
          ).then((_) => _loadDashboardData()),
        ),
      ],
    );
  }

  Widget _buildActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildPendingList(ThemeData theme) {
    return Column(
      children: _recentPending.map((item) {
        final student = item['student'] as Student;
        final fee = item['fee'] as Fee;
        final isOverdue = fee.isOverdue;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isOverdue 
                  ? Colors.red.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              child: Icon(
                isOverdue ? Icons.warning : Icons.schedule,
                color: isOverdue ? Colors.red : Colors.orange,
              ),
            ),
            title: Text(student.name),
            subtitle: Text(
              '${fee.month} • Due: ${DateFormat('dd MMM').format(fee.dueDate)}',
              style: TextStyle(
                color: isOverdue ? Colors.red : null,
              ),
            ),
            trailing: Text(
              '₹${fee.amount}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isOverdue ? Colors.red : Colors.orange,
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CollectFeeScreen(
                  studentId: student.id,
                  feeId: fee.id,
                ),
              ),
            ).then((_) => _loadDashboardData()),
          ),
        );
      }).toList(),
    );
  }
}
