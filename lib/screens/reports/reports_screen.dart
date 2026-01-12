import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/fee.dart';
import '../../services/export_service.dart';

/// Screen for viewing reports and exporting data
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  String _selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  Map<String, dynamic> _monthlyStats = {};
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<String> _getMonthOptions() {
    final months = <String>[];
    final now = DateTime.now();
    
    // Last 12 months
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add(DateFormat('MMMM yyyy').format(date));
    }
    
    return months;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final fees = await _db.getFeesByMonth(_selectedMonth);
      final students = await _db.getAllStudents(activeOnly: true);
      final pendingFees = await _db.getPendingFees();
      
      // Calculate stats
      final totalExpected = students.fold<int>(0, (sum, s) => sum + s.monthlyFee);
      final collected = fees
          .where((f) => f.status == PaymentStatus.paid)
          .fold<int>(0, (sum, f) => sum + f.amount);
      final pending = fees
          .where((f) => f.status != PaymentStatus.paid)
          .fold<int>(0, (sum, f) => sum + f.amount);
      
      final paidStudents = fees.where((f) => f.status == PaymentStatus.paid).length;
      final pendingStudents = fees.where((f) => f.status != PaymentStatus.paid).length;
      
      // Get attendance stats for the month
      final attendanceStats = await _db.getTodayAttendanceSummary(); // Simplified for now
      
      setState(() {
        _monthlyStats = {
          'totalStudents': students.length,
          'totalExpected': totalExpected,
          'collected': collected,
          'pending': pending,
          'paidStudents': paidStudents,
          'pendingStudents': pendingStudents,
          'collectionRate': totalExpected > 0 
              ? (collected / totalExpected * 100).round()
              : 0,
          'overdueFees': pendingFees.where((f) => f.isOverdue).length,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportStudents() async {
    setState(() => _isExporting = true);
    
    try {
      final csv = await ExportService.exportStudentsToCSV();
      await ExportService.saveAndShareCSV(
        csv,
        'blue_academy_students_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
    
    setState(() => _isExporting = false);
  }

  Future<void> _exportMonthlyReport() async {
    setState(() => _isExporting = true);
    
    try {
      final csv = await ExportService.exportMonthlyReportToCSV(_selectedMonth);
      await ExportService.saveAndShareCSV(
        csv,
        'blue_academy_report_${_selectedMonth.replaceAll(' ', '_')}.csv',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
    
    setState(() => _isExporting = false);
  }

  Future<void> _exportPendingFees() async {
    setState(() => _isExporting = true);
    
    try {
      final csv = await ExportService.exportFeesToCSV();
      await ExportService.saveAndShareCSV(
        csv,
        'blue_academy_pending_fees_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting: $e')),
        );
      }
    }
    
    setState(() => _isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthOptions = _getMonthOptions();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month selector
                  DropdownButtonFormField<String>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Select Month',
                      prefixIcon: Icon(Icons.calendar_month),
                    ),
                    items: monthOptions.map((month) {
                      return DropdownMenuItem(
                        value: month,
                        child: Text(month),
                      );
                    }).toList(),
                    onChanged: (month) {
                      if (month != null) {
                        setState(() => _selectedMonth = month);
                        _loadData();
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Collection Overview
                  Text(
                    'Collection Overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildCollectionCard(theme),
                  const SizedBox(height: 16),
                  
                  // Stats Grid
                  GridView.count(
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
                        value: '${_monthlyStats['totalStudents'] ?? 0}',
                        color: theme.colorScheme.primary,
                      ),
                      _buildStatCard(
                        theme,
                        icon: Icons.check_circle,
                        label: 'Paid',
                        value: '${_monthlyStats['paidStudents'] ?? 0}',
                        color: Colors.green,
                      ),
                      _buildStatCard(
                        theme,
                        icon: Icons.pending,
                        label: 'Pending',
                        value: '${_monthlyStats['pendingStudents'] ?? 0}',
                        color: Colors.orange,
                      ),
                      _buildStatCard(
                        theme,
                        icon: Icons.warning,
                        label: 'Overdue',
                        value: '${_monthlyStats['overdueFees'] ?? 0}',
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Export Options
                  Text(
                    'Export Data',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildExportCard(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildCollectionCard(ThemeData theme) {
    final collected = _monthlyStats['collected'] ?? 0;
    final expected = _monthlyStats['totalExpected'] ?? 0;
    final pending = _monthlyStats['pending'] ?? 0;
    final rate = _monthlyStats['collectionRate'] ?? 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAmountColumn('Expected', expected, theme.colorScheme.primary),
                Container(
                  height: 50,
                  width: 1,
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
                _buildAmountColumn('Collected', collected, Colors.green),
                Container(
                  height: 50,
                  width: 1,
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
                _buildAmountColumn('Pending', pending, Colors.orange),
              ],
            ),
            const SizedBox(height: 20),
            
            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Collection Rate'),
                    Text(
                      '$rate%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getProgressColor(rate),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 10,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(_getProgressColor(rate)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(int rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildAmountColumn(String label, int amount, Color color) {
    return Column(
      children: [
        Text(
          '₹$amount',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
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
              color.withOpacity(0.15),
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
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildExportOption(
              icon: Icons.people,
              title: 'Export Students',
              subtitle: 'All student details as CSV',
              onTap: _isExporting ? null : _exportStudents,
            ),
            const Divider(),
            _buildExportOption(
              icon: Icons.receipt_long,
              title: 'Export Monthly Report',
              subtitle: 'Fee collection for $_selectedMonth',
              onTap: _isExporting ? null : _exportMonthlyReport,
            ),
            const Divider(),
            _buildExportOption(
              icon: Icons.pending_actions,
              title: 'Export Pending Fees',
              subtitle: 'All pending payments',
              onTap: _isExporting ? null : _exportPendingFees,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: _isExporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download),
      onTap: onTap,
    );
  }
}
