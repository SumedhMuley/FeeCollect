import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/student.dart';
import '../../models/fee.dart';
import '../../services/reminder_service.dart';
import 'collect_fee_screen.dart';

/// Screen showing all pending/overdue fees with reminder actions
class PendingFeesScreen extends StatefulWidget {
  const PendingFeesScreen({super.key});

  @override
  State<PendingFeesScreen> createState() => _PendingFeesScreenState();
}

class _PendingFeesScreenState extends State<PendingFeesScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  List<Map<String, dynamic>> _pendingItems = [];
  bool _isLoading = true;
  bool _showOverdueOnly = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final fees = _showOverdueOnly 
          ? await _db.getOverdueFees()
          : await _db.getPendingFees();
      
      final List<Map<String, dynamic>> items = [];
      
      for (final fee in fees) {
        final student = await _db.getStudentById(fee.studentId);
        if (student != null) {
          items.add({'student': student, 'fee': fee});
        }
      }
      
      // Sort by overdue first, then by due date
      items.sort((a, b) {
        final feeA = a['fee'] as Fee;
        final feeB = b['fee'] as Fee;
        
        // Overdue items first
        if (feeA.isOverdue && !feeB.isOverdue) return -1;
        if (!feeA.isOverdue && feeB.isOverdue) return 1;
        
        // Then by due date
        return feeA.dueDate.compareTo(feeB.dueDate);
      });
      
      setState(() {
        _pendingItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int get _totalPending {
    return _pendingItems.fold<int>(
      0, 
      (sum, item) => sum + (item['fee'] as Fee).amount,
    );
  }

  int get _overdueCount {
    return _pendingItems.where((item) => (item['fee'] as Fee).isOverdue).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Payments'),
        actions: [
          IconButton(
            icon: Icon(
              _showOverdueOnly ? Icons.warning : Icons.warning_outlined,
              color: _showOverdueOnly ? Colors.red : null,
            ),
            tooltip: _showOverdueOnly ? 'Show all pending' : 'Show overdue only',
            onPressed: () {
              setState(() => _showOverdueOnly = !_showOverdueOnly);
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingItems.isEmpty
              ? _buildEmptyState(theme)
              : Column(
                  children: [
                    // Summary card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withOpacity(0.2),
                            Colors.red.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            'Total Pending',
                            '₹$_totalPending',
                            Colors.orange,
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                          _buildSummaryItem(
                            'Students',
                            '${_pendingItems.length}',
                            theme.colorScheme.primary,
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                          _buildSummaryItem(
                            'Overdue',
                            '$_overdueCount',
                            Colors.red,
                          ),
                        ],
                      ),
                    ),
                    
                    // List
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _pendingItems.length,
                          itemBuilder: (context, index) {
                            return _buildPendingCard(
                              _pendingItems[index],
                              theme,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'All fees collected! 🎉',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending payments',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> item, ThemeData theme) {
    final student = item['student'] as Student;
    final fee = item['fee'] as Fee;
    final isOverdue = fee.isOverdue;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOverdue 
            ? const BorderSide(color: Colors.red, width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isOverdue 
                      ? Colors.red.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  child: Text(
                    student.name[0].toUpperCase(),
                    style: TextStyle(
                      color: isOverdue ? Colors.red : Colors.orange,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        fee.month,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${fee.amount}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isOverdue ? Colors.red : Colors.orange,
                      ),
                    ),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'OVERDUE',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Due date
            Row(
              children: [
                Icon(
                  Icons.event,
                  size: 16,
                  color: isOverdue ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Due: ${DateFormat('dd MMM yyyy').format(fee.dueDate)}',
                  style: TextStyle(
                    color: isOverdue ? Colors.red : Colors.grey,
                  ),
                ),
                if (isOverdue) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${DateTime.now().difference(fee.dueDate).inDays} days overdue)',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendWhatsAppReminder(student, fee),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                      side: const BorderSide(color: Colors.teal),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendSMSReminder(student, fee),
                    icon: const Icon(Icons.sms, size: 18),
                    label: const Text('SMS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CollectFeeScreen(
                          studentId: student.id,
                          feeId: fee.id,
                        ),
                      ),
                    ).then((_) => _loadData()),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Collect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsAppReminder(Student student, Fee fee) async {
    final success = await ReminderService.sendWhatsAppReminder(
      student: student,
      fee: fee,
    );
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _sendSMSReminder(Student student, Fee fee) async {
    final success = await ReminderService.sendSMSReminder(
      student: student,
      fee: fee,
    );
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open SMS app')),
      );
    }
  }
}
