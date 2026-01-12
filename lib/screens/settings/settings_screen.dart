import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import '../../services/export_service.dart';
import '../../database/database_helper.dart';

/// Settings screen for app configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  String _academyName = 'Blue Academy';
  int _defaultMonthlyFee = 1000;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      final hour = prefs.getInt('notification_hour') ?? 9;
      final minute = prefs.getInt('notification_minute') ?? 0;
      _notificationTime = TimeOfDay(hour: hour, minute: minute);
      _academyName = prefs.getString('academy_name') ?? 'Blue Academy';
      _defaultMonthlyFee = prefs.getInt('default_monthly_fee') ?? 1000;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setInt('notification_hour', _notificationTime.hour);
    await prefs.setInt('notification_minute', _notificationTime.minute);
    await prefs.setString('academy_name', _academyName);
    await prefs.setInt('default_monthly_fee', _defaultMonthlyFee);
    
    // Update notification schedule
    final notificationService = NotificationService();
    if (_notificationsEnabled) {
      await notificationService.scheduleDailyReminder(
        hour: _notificationTime.hour,
        minute: _notificationTime.minute,
      );
    } else {
      await notificationService.cancelAll();
    }
  }

  Future<void> _selectNotificationTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      helpText: 'Select daily reminder time',
    );
    
    if (time != null) {
      setState(() => _notificationTime = time);
      await _saveSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder set for ${time.format(context)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _editAcademyName() async {
    final controller = TextEditingController(text: _academyName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Academy Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter academy name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() => _academyName = result);
      await _saveSettings();
    }
  }

  Future<void> _editDefaultFee() async {
    final controller = TextEditingController(text: _defaultMonthlyFee.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Monthly Fee'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter amount',
            prefixText: '₹ ',
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result != null && result > 0) {
      setState(() => _defaultMonthlyFee = result);
      await _saveSettings();
    }
  }

  Future<void> _exportAllData() async {
    try {
      final csv = await ExportService.exportStudentsToCSV();
      await ExportService.saveAndShareCSV(csv, 'students_export.csv');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data exported successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all students, fees, attendance, and batches. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await DatabaseHelper.instance.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Notifications Section
          _buildSectionHeader('Notifications', theme),
          SwitchListTile(
            title: const Text('Daily Reminders'),
            subtitle: const Text('Get notified about pending payments'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              _saveSettings();
            },
          ),
          ListTile(
            title: const Text('Reminder Time'),
            subtitle: Text(_notificationTime.format(context)),
            trailing: const Icon(Icons.chevron_right),
            enabled: _notificationsEnabled,
            onTap: _notificationsEnabled ? _selectNotificationTime : null,
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Test Notification'),
            subtitle: const Text('Send a test notification now'),
            enabled: _notificationsEnabled,
            onTap: _notificationsEnabled ? () async {
              final notificationService = NotificationService();
              await notificationService.showNotification(
                id: 999,
                title: '🔔 Test Notification',
                body: 'Notifications are working! Your reminder is set for ${_notificationTime.format(context)}.',
                payload: 'test',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test notification sent! Check your notification panel.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } : null,
          ),
          const Divider(),
          
          // Academy Settings
          _buildSectionHeader('Academy', theme),
          ListTile(
            title: const Text('Academy Name'),
            subtitle: Text(_academyName),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editAcademyName,
          ),
          ListTile(
            title: const Text('Default Monthly Fee'),
            subtitle: Text('₹$_defaultMonthlyFee'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editDefaultFee,
          ),
          const Divider(),
          
          // Data Management
          _buildSectionHeader('Data Management', theme),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Export All Data'),
            subtitle: const Text('Save data as CSV file'),
            onTap: _exportAllData,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Data', 
              style: TextStyle(color: Colors.red)),
            subtitle: const Text('Delete all students, fees, and attendance'),
            onTap: _confirmClearData,
          ),
          const Divider(),
          
          // About Section
          _buildSectionHeader('About', theme),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Developer'),
            subtitle: const Text('Blue Academy Team'),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
