import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/student.dart';
import '../../models/fee.dart';

/// Screen for collecting fee from a student
class CollectFeeScreen extends StatefulWidget {
  final int? studentId;
  final int? feeId; // If editing existing fee
  
  const CollectFeeScreen({super.key, this.studentId, this.feeId});

  @override
  State<CollectFeeScreen> createState() => _CollectFeeScreenState();
}

class _CollectFeeScreenState extends State<CollectFeeScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();
  
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  
  List<Student> _students = [];
  Student? _selectedStudent;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 5));
  String _selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  PaymentStatus _status = PaymentStatus.pending;
  DateTime? _paidDate;
  Fee? _existingFee;
  
  bool _isLoading = true;
  bool _isSaving = false;

  bool get isEditing => widget.feeId != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<String> _getMonthOptions() {
    final months = <String>[];
    final now = DateTime.now();
    
    // Past 3 months, current, and next 2 months
    for (int i = -3; i <= 2; i++) {
      final date = DateTime(now.year, now.month + i, 1);
      months.add(DateFormat('MMMM yyyy').format(date));
    }
    
    return months;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final students = await _db.getAllStudents(activeOnly: true);
      
      if (isEditing && widget.feeId != null) {
        // Load existing fee - we need to find it
        final allFees = await _db.getPendingFees();
        _existingFee = allFees.where((f) => f.id == widget.feeId).firstOrNull;
        
        if (_existingFee != null) {
          _selectedStudent = students.where(
            (s) => s.id == _existingFee!.studentId
          ).firstOrNull;
          _amountController.text = _existingFee!.amount.toString();
          _selectedMonth = _existingFee!.month;
          _dueDate = _existingFee!.dueDate;
          _status = _existingFee!.status;
          _paidDate = _existingFee!.paidDate;
          _notesController.text = _existingFee!.notes ?? '';
        }
      } else if (widget.studentId != null) {
        _selectedStudent = students.where(
          (s) => s.id == widget.studentId
        ).firstOrNull;
        
        if (_selectedStudent != null) {
          _amountController.text = _selectedStudent!.monthlyFee.toString();
        }
      }
      
      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _saveFee() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final fee = Fee(
        id: _existingFee?.id,
        studentId: _selectedStudent!.id!,
        amount: int.parse(_amountController.text.trim()),
        dueDate: _dueDate,
        paidDate: _status == PaymentStatus.paid ? (_paidDate ?? DateTime.now()) : null,
        status: _status,
        month: _selectedMonth,
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );
      
      if (isEditing) {
        await _db.updateFee(fee);
      } else {
        await _db.insertFee(fee);
      }
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _status == PaymentStatus.paid
                  ? 'Payment recorded successfully'
                  : 'Fee added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving fee: $e')),
        );
      }
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _selectPaidDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() => _paidDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthOptions = _getMonthOptions();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Update Payment' : 'Collect Fee'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Student selection
                  DropdownButtonFormField<Student>(
                    value: _selectedStudent,
                    decoration: const InputDecoration(
                      labelText: 'Select Student *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: _students.map((student) {
                      return DropdownMenuItem(
                        value: student,
                        child: Text('${student.name} (₹${student.monthlyFee}/month)'),
                      );
                    }).toList(),
                    onChanged: isEditing 
                        ? null 
                        : (student) {
                            setState(() {
                              _selectedStudent = student;
                              if (student != null) {
                                _amountController.text = student.monthlyFee.toString();
                              }
                            });
                          },
                    validator: (value) {
                      if (value == null) return 'Please select a student';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Month selection
                  DropdownButtonFormField<String>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'For Month *',
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
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Amount
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixIcon: Icon(Icons.currency_rupee),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Please enter amount';
                      }
                      if (int.tryParse(value!.trim()) == null) {
                        return 'Please enter valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Due date
                  InkWell(
                    onTap: _selectDueDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        prefixIcon: Icon(Icons.event),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_dueDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Payment Status
                  Text(
                    'Payment Status',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Wrap(
                    spacing: 8,
                    children: PaymentStatus.values.map((status) {
                      final isSelected = _status == status;
                      Color color;
                      switch (status) {
                        case PaymentStatus.paid:
                          color = Colors.green;
                          break;
                        case PaymentStatus.pending:
                          color = Colors.orange;
                          break;
                        case PaymentStatus.overdue:
                          color = Colors.red;
                          break;
                        case PaymentStatus.partial:
                          color = Colors.blue;
                          break;
                      }
                      
                      return ChoiceChip(
                        label: Text(status.displayName),
                        selected: isSelected,
                        selectedColor: color.withOpacity(0.3),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _status = status;
                              if (status == PaymentStatus.paid && _paidDate == null) {
                                _paidDate = DateTime.now();
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Paid date (only if status is paid)
                  if (_status == PaymentStatus.paid) ...[
                    InkWell(
                      onTap: _selectPaidDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Paid Date',
                          prefixIcon: Icon(Icons.check_circle),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy').format(_paidDate ?? DateTime.now()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  
                  // Quick actions for marking paid
                  if (_status != PaymentStatus.paid)
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _status = PaymentStatus.paid;
                          _paidDate = DateTime.now();
                        });
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      label: const Text('Mark as Paid'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // Save button
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveFee,
                    icon: _isSaving 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_status == PaymentStatus.paid 
                            ? Icons.check 
                            : Icons.save),
                    label: Text(
                      _status == PaymentStatus.paid
                          ? 'Record Payment'
                          : (isEditing ? 'Update Fee' : 'Add Fee'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
