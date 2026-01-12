import 'package:url_launcher/url_launcher.dart';
import '../models/student.dart';
import '../models/fee.dart';
import 'package:intl/intl.dart';

/// Service for sending payment reminders via WhatsApp and SMS
class ReminderService {
  static const String _coachingName = 'Blue Academy';

  /// Generate payment reminder message
  static String generateReminderMessage({
    required Student student,
    required Fee fee,
    String? customMessage,
  }) {
    final dueDateFormatted = DateFormat('dd MMM yyyy').format(fee.dueDate);
    final guardianName = student.guardianName ?? student.name;
    
    return customMessage ?? '''
Hi $guardianName,

This is a reminder for $_coachingName fee payment.

Student: ${student.name}
Amount Due: ₹${fee.amount}
For Month: ${fee.month}
Due Date: $dueDateFormatted

Please make the payment at your earliest convenience.

Thank you!
$_coachingName''';
  }

  /// Generate payment confirmation message
  static String generatePaymentConfirmation({
    required Student student,
    required Fee fee,
  }) {
    final paidDateFormatted = fee.paidDate != null 
        ? DateFormat('dd MMM yyyy').format(fee.paidDate!)
        : DateFormat('dd MMM yyyy').format(DateTime.now());
    
    return '''
Hi ${student.guardianName ?? student.name},

Thank you for the payment!

Student: ${student.name}
Amount Paid: ₹${fee.amount}
For Month: ${fee.month}
Date: $paidDateFormatted

Receipt No: #${fee.id ?? DateTime.now().millisecondsSinceEpoch}

Thank you!
$_coachingName''';
  }

  /// Send WhatsApp reminder
  static Future<bool> sendWhatsAppReminder({
    required Student student,
    required Fee fee,
    String? customMessage,
  }) async {
    final phone = student.guardianPhone ?? student.phone;
    final message = generateReminderMessage(
      student: student,
      fee: fee,
      customMessage: customMessage,
    );
    
    return await _openWhatsApp(phone, message);
  }

  /// Send WhatsApp payment confirmation
  static Future<bool> sendWhatsAppConfirmation({
    required Student student,
    required Fee fee,
  }) async {
    final phone = student.guardianPhone ?? student.phone;
    final message = generatePaymentConfirmation(student: student, fee: fee);
    
    return await _openWhatsApp(phone, message);
  }

  /// Send SMS reminder
  static Future<bool> sendSMSReminder({
    required Student student,
    required Fee fee,
    String? customMessage,
  }) async {
    final phone = student.guardianPhone ?? student.phone;
    final message = generateReminderMessage(
      student: student,
      fee: fee,
      customMessage: customMessage,
    );
    
    return await _openSMS(phone, message);
  }

  /// Make a phone call
  static Future<bool> makeCall(String phone) async {
    // Clean phone number - remove spaces, dashes
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  /// Open WhatsApp with pre-filled message
  static Future<bool> _openWhatsApp(String phone, String message) async {
    // Clean phone number - remove spaces, dashes
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Add country code if not present (assuming India +91)
    if (!cleanPhone.startsWith('+')) {
      if (cleanPhone.startsWith('0')) {
        cleanPhone = cleanPhone.substring(1);
      }
      cleanPhone = '+91$cleanPhone';
    }
    
    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = 'https://wa.me/$cleanPhone?text=$encodedMessage';
    final uri = Uri.parse(whatsappUrl);
    
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Open SMS app with pre-filled message
  static Future<bool> _openSMS(String phone, String message) async {
    // Clean phone number
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final encodedMessage = Uri.encodeComponent(message);
    
    // Try sms: URI scheme
    final smsUri = Uri.parse('sms:$cleanPhone?body=$encodedMessage');
    
    if (await canLaunchUrl(smsUri)) {
      return await launchUrl(smsUri);
    }
    return false;
  }

  /// Generate bulk reminder for multiple students with pending fees
  static String generateBulkReminderPreview(List<Map<String, dynamic>> pendingList) {
    final buffer = StringBuffer();
    buffer.writeln('Pending Payments Summary:');
    buffer.writeln('========================');
    
    for (final item in pendingList) {
      final student = item['student'] as Student;
      final fee = item['fee'] as Fee;
      buffer.writeln('${student.name}: ₹${fee.amount} (${fee.month})');
    }
    
    buffer.writeln('========================');
    buffer.writeln('Total: ${pendingList.length} pending');
    
    return buffer.toString();
  }
}
