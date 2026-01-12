import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/student.dart';
import '../../models/batch.dart';

/// Screen for adding or editing a student
class AddStudentScreen extends StatefulWidget {
  final int? studentId; // If provided, we're editing
  
  const AddStudentScreen({super.key, this.studentId});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _feeController = TextEditingController();
  final _notesController = TextEditingController();
  
  List<Batch> _batches = [];
  int? _selectedBatchId;
  String? _selectedSport;
  DateTime _joinDate = DateTime.now();
  bool _isActive = true;
  bool _isLoading = false;
  bool _isSaving = false;
  
  final List<String> _sports = [
    'Swimming',
    'Cricket',
    'Football',
    'Tennis',
    'Badminton',
    'Basketball',
    'Athletics',
    'Other',
  ];

  bool get isEditing => widget.studentId != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final List<Batch> batches = await _db.getAllBatches(activeOnly: true);
      
      if (isEditing) {
        final student = await _db.getStudentById(widget.studentId!);
        if (student != null) {
          _nameController.text = student.name;
          _phoneController.text = student.phone;
          _emailController.text = student.email ?? '';
          _guardianNameController.text = student.guardianName ?? '';
          _guardianPhoneController.text = student.guardianPhone ?? '';
          _feeController.text = student.monthlyFee.toString();
          _notesController.text = student.notes ?? '';
          _selectedBatchId = student.batchId;
          _selectedSport = student.sport;
          _joinDate = student.joinDate;
          _isActive = student.isActive;
        }
      }
      
      setState(() {
        _batches = batches;
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

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final student = Student(
        id: widget.studentId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty 
            ? null 
            : _emailController.text.trim(),
        guardianName: _guardianNameController.text.trim().isEmpty 
            ? null 
            : _guardianNameController.text.trim(),
        guardianPhone: _guardianPhoneController.text.trim().isEmpty 
            ? null 
            : _guardianPhoneController.text.trim(),
        batchId: _selectedBatchId,
        monthlyFee: int.parse(_feeController.text.trim()),
        joinDate: _joinDate,
        isActive: _isActive,
        sport: _selectedSport,
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );
      
      if (isEditing) {
        await _db.updateStudent(student);
      } else {
        await _db.insertStudent(student);
      }
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing 
                  ? 'Student updated successfully'
                  : 'Student added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving student: $e')),
        );
      }
    }
  }

  Future<void> _selectJoinDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() => _joinDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Student' : 'Add Student'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Basic Info Section
                  _buildSectionHeader(theme, 'Basic Information'),
                  const SizedBox(height: 12),
                  
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Student Name *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Please enter student name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Please enter phone number';
                      }
                      if (value!.trim().length < 10) {
                        return 'Please enter valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (Optional)',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  
                  // Guardian Info Section
                  _buildSectionHeader(theme, 'Guardian Information'),
                  const SizedBox(height: 12),
                  
                  TextFormField(
                    controller: _guardianNameController,
                    decoration: const InputDecoration(
                      labelText: 'Guardian Name',
                      prefixIcon: Icon(Icons.family_restroom),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _guardianPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Guardian Phone',
                      prefixIcon: Icon(Icons.phone_android),
                      helperText: 'Used for sending reminders',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  
                  // Coaching Info Section
                  _buildSectionHeader(theme, 'Coaching Details'),
                  const SizedBox(height: 12),
                  
                  // Sport dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedSport,
                    decoration: const InputDecoration(
                      labelText: 'Sport',
                      prefixIcon: Icon(Icons.sports),
                    ),
                    items: _sports.map((sport) {
                      return DropdownMenuItem(
                        value: sport,
                        child: Text(sport),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedSport = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Batch dropdown
                  DropdownButtonFormField<int>(
                    value: _selectedBatchId,
                    decoration: const InputDecoration(
                      labelText: 'Batch',
                      prefixIcon: Icon(Icons.groups),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('No Batch'),
                      ),
                      ..._batches.map((batch) {
                        return DropdownMenuItem(
                          value: batch.id,
                          child: Text('${batch.name} (${batch.timing})'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedBatchId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _feeController,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Fee *',
                      prefixIcon: Icon(Icons.currency_rupee),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Please enter monthly fee';
                      }
                      if (int.tryParse(value!.trim()) == null) {
                        return 'Please enter valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Join date picker
                  InkWell(
                    onTap: _selectJoinDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Join Date',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_joinDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Active toggle
                  if (isEditing)
                    SwitchListTile(
                      title: const Text('Active Student'),
                      subtitle: const Text('Inactive students won\'t appear in attendance'),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() => _isActive = value);
                      },
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Save button
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveStudent,
                    icon: _isSaving 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(isEditing ? 'Update Student' : 'Add Student'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student?'),
        content: const Text(
          'This will also delete all fee records and attendance for this student. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && widget.studentId != null) {
      await _db.deleteStudent(widget.studentId!);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student deleted')),
        );
      }
    }
  }
}
