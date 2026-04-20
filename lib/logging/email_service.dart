// lib/logging/email_service.dart
// Email service for sending monthly log reports via Gmail
// Explanation for Flutter Developers:
// Sending emails from a backend is similar to sending notifications in Flutter.
// Here we use SMTP (Simple Mail Transfer Protocol) to send emails via Gmail.

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:archive/archive.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../config.dart';
import 'logger.dart';

/// Email service for sending monthly log reports
class EmailService {
  static bool get isConfigured =>
      globalConfig.gmailEmail.trim().isNotEmpty &&
      globalConfig.gmailPassword.trim().isNotEmpty;

  static String get configurationStatus {
    if (!isConfigured) {
      return 'Not configured. Set email.email/email.password in config.yaml or SHADOW_GMAIL_EMAIL/SHADOW_GMAIL_PASSWORD in the environment.';
    }

    return 'Configured for Gmail SMTP as ${globalConfig.gmailEmail}. Use a Gmail app password for sending.';
  }

  /// Send monthly log export to admin email
  /// Called automatically on the 1st of each month
  static Future<bool> sendMonthlyLogReport(String adminEmail) async {
    try {
      if (!isConfigured) {
        print('[EMAIL] Gmail credentials not configured');
        return false;
      }

      print('[EMAIL] Preparing monthly log report for $adminEmail...');

      // Get all log files
      final logFiles = await logger.getLogFiles();
      if (logFiles.isEmpty) {
        print('[EMAIL] No log files to send');
        return false;
      }

      // Create archive of logs
      final archivePath = await _createLogArchive(logFiles);

      // Send email via Gmail SMTP
      final smtpServer =
          gmail(globalConfig.gmailEmail, globalConfig.gmailPassword);

      final message = Message()
        ..from = Address(globalConfig.gmailEmail, 'Shadow App Backend')
        ..recipients.add(adminEmail)
        ..subject =
            '[Shadow App] Monthly Log Report - ${DateTime.now().toIso8601String().substring(0, 7)}'
        ..html = _buildEmailBody()
        ..attachments.add(FileAttachment(File(archivePath)));

      try {
        await send(message, smtpServer);
        print('[EMAIL] Monthly log report sent to $adminEmail');
        return true;
      } on MailerException catch (e) {
        print('[EMAIL ERROR] Failed to send email: $e');
        for (var p in e.problems) {
          print('[EMAIL ERROR] Problem: ${p.code}: ${p.msg}');
        }
        return false;
      }
    } catch (e) {
      print('[EMAIL ERROR] Email service error: $e');
      return false;
    }
  }

  /// Build HTML email body
  static String _buildEmailBody() {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1);

    return '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; color: #333; }
    h1 { color: #0066cc; }
    .section { margin: 20px 0; padding: 10px; border: 1px solid #eee; }
    .stats { display: flex; gap: 20px; }
    .stat-box { background: #f5f5f5; padding: 10px; border-radius: 5px; }
    .stat-label { font-size: 12px; color: #666; }
    .stat-value { font-size: 24px; font-weight: bold; color: #0066cc; }
  </style>
</head>
<body>
  <h1>Shadow App Backend - Monthly Log Report</h1>
  
  <div class="section">
    <h2>Report Period</h2>
    <p><strong>Month:</strong> ${previousMonth.toIso8601String().substring(0, 7)}</p>
    <p><strong>Generated:</strong> ${now.toIso8601String()}</p>
  </div>

  <div class="section">
    <h2>What's Included</h2>
    <ul>
      <li>Complete audit logs for the month</li>
      <li>User activity records</li>
      <li>Database operations</li>
      <li>Error and failure logs</li>
    </ul>
  </div>

  <div class="section">
    <h2>Log Archive</h2>
    <p>Attached: <code>shadow_app_logs_${previousMonth.toIso8601String().substring(0, 7)}.tar.gz</code></p>
    <p>This archive contains all log files for the reporting period.</p>
  </div>

  <div class="section" style="background: #f0f0f0; border-left: 4px solid #0066cc;">
    <p><strong>Note:</strong> These logs are automatically archived and sent monthly for compliance and monitoring purposes.</p>
    <p><em>Shadow App Backend v0.1.0</em></p>
  </div>
</body>
</html>
    ''';
  }

  /// Create a compressed archive of log files
  static Future<String> _createLogArchive(List<File> files) async {
    final timestamp = DateTime.now().toIso8601String().substring(0, 10);
    final archivePath = path.join(
      globalConfig.logFilePath,
      'shadow_app_logs_$timestamp.tar.gz',
    );

    print('[EMAIL] Creating archive at: $archivePath');

    // Create a tar archive
    final archive = Archive();

    for (final file in files) {
      final bytes = await file.readAsBytes();
      final archiveFile = ArchiveFile(
        path.basename(file.path),
        bytes.length,
        bytes,
      );
      archive.addFile(archiveFile);
    }

    // Encode as tar
    final tarBytes = TarEncoder().encode(archive);

    // Compress with gzip
    final gzipBytes = GZipEncoder().encode(tarBytes);

    // Write to file
    final archiveFile = File(archivePath);
    await archiveFile.writeAsBytes(gzipBytes!);

    print(
        '[EMAIL] Archive created: ${archiveFile.path} (${gzipBytes.length} bytes)');
    return archivePath;
  }

  /// Test email sending (for manual verification)
  static Future<bool> testEmail(String to) async {
    try {
      if (!isConfigured) {
        print('[EMAIL] Gmail credentials not configured');
        return false;
      }

      print('[EMAIL] Sending test email to $to...');

      final smtpServer =
          gmail(globalConfig.gmailEmail, globalConfig.gmailPassword);

      final message = Message()
        ..from = Address(globalConfig.gmailEmail, 'Shadow App Backend')
        ..recipients.add(to)
        ..subject = '[Test] Shadow App Backend is operational'
        ..html = '''
    <h1>Test Email</h1>
    <p>This is a test email from Shadow App Backend.</p>
    <p>If you received this, email integration is working correctly.</p>
    <p>Sent at: ${DateTime.now()}</p>
        ''';

      try {
        await send(message, smtpServer);
        print('[EMAIL] Test email sent successfully');
        return true;
      } on MailerException catch (e) {
        print('[EMAIL ERROR] Failed to send test email: $e');
        return false;
      }
    } catch (e) {
      print('[EMAIL ERROR] Test email error: $e');
      return false;
    }
  }

  /// Schedule monthly log email send
  static Future<void> scheduleMonthlyReport(String adminEmail) async {
    // Calculate time until 1st of next month at 2 AM
    final now = DateTime.now();
    DateTime nextRun;

    if (now.day == 1) {
      // Already on the 1st, send now
      nextRun = now.add(Duration(seconds: 10));
    } else {
      // Calculate next 1st of month
      nextRun = DateTime(now.year, now.month + 1, 1, 2, 0, 0);
    }

    final delayUntilNextRun = nextRun.difference(now);
    print(
        '[EMAIL] Monthly report scheduled for ${nextRun.toIso8601String()} (in ${delayUntilNextRun.inHours} hours)');

    // Schedule the email send
    Future.delayed(delayUntilNextRun, () async {
      await sendMonthlyLogReport(adminEmail);
      // Reschedule for next month (fire and forget)
      // ignore: unawaited_futures
      scheduleMonthlyReport(adminEmail);
    });
  }

  /// Send a generated admin report bundle to a recipient.
  static Future<bool> sendAdminReportBundle({
    required String to,
    required String bundlePath,
  }) async {
    try {
      if (!isConfigured) {
        print('[EMAIL] Gmail credentials not configured');
        return false;
      }

      final bundleFile = File(bundlePath);
      if (!await bundleFile.exists()) {
        print('[EMAIL ERROR] Report bundle not found: $bundlePath');
        return false;
      }

      print('[EMAIL] Sending admin report bundle to $to...');

      final smtpServer =
          gmail(globalConfig.gmailEmail, globalConfig.gmailPassword);

      final message = Message()
        ..from = Address(globalConfig.gmailEmail, 'Shadow App Backend')
        ..recipients.add(to)
        ..subject =
            '[Shadow App] Admin report bundle - ${DateTime.now().toIso8601String().substring(0, 19)}'
        ..html = _buildAdminReportEmailBody(path.basename(bundlePath))
        ..attachments.add(FileAttachment(bundleFile));

      try {
        await send(message, smtpServer);
        print('[EMAIL] Admin report bundle sent to $to');
        return true;
      } on MailerException catch (e) {
        print('[EMAIL ERROR] Failed to send admin report bundle: $e');
        for (var p in e.problems) {
          print('[EMAIL ERROR] Problem: ${p.code}: ${p.msg}');
        }
        return false;
      }
    } catch (e) {
      print('[EMAIL ERROR] Admin report bundle send failed: $e');
      return false;
    }
  }

  static String _buildAdminReportEmailBody(String attachmentName) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; color: #333; }
    h1 { color: #0066cc; }
    .section { margin: 20px 0; padding: 10px; border: 1px solid #eee; }
  </style>
</head>
<body>
  <h1>Shadow App Backend - Admin Report Bundle</h1>

  <div class="section">
    <p><strong>Generated:</strong> ${DateTime.now().toIso8601String()}</p>
    <p><strong>Attachment:</strong> <code>$attachmentName</code></p>
  </div>

  <div class="section">
    <h2>Included Data</h2>
    <ul>
      <li>Current SQLite database snapshot files</li>
      <li>Audit log files</li>
      <li>JSON exports for users, collections, documents, and audit log</li>
      <li>Storage and export metadata</li>
    </ul>
  </div>

  <div class="section" style="background: #fff7e6; border-left: 4px solid #cc7a00;">
    <p><strong>Confidential:</strong> This bundle contains administrative data and should be stored securely.</p>
  </div>
</body>
</html>
    ''';
  }
}
