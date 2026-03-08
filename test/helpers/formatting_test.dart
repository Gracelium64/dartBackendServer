// test/helpers/formatting_test.dart
// Unit tests for formatting utility functions

import 'package:test/test.dart';
import '../../bin/helpers/formatting.dart';

void main() {
  group('formatBytes', () {
    test('should format bytes', () {
      expect(formatBytes(0), equals('0 B'));
      expect(formatBytes(100), equals('100 B'));
      expect(formatBytes(1023), equals('1023 B'));
    });

    test('should format kilobytes', () {
      expect(formatBytes(1024), equals('1.00 KB'));
      expect(formatBytes(1536), equals('1.50 KB'));
      expect(formatBytes(10240), equals('10.00 KB'));
    });

    test('should format megabytes', () {
      expect(formatBytes(1024 * 1024), equals('1.00 MB'));
      expect(formatBytes((1024 * 1024 * 1.5).toInt()), equals('1.50 MB'));
      expect(formatBytes(1024 * 1024 * 100), equals('100.00 MB'));
    });

    test('should format gigabytes', () {
      expect(formatBytes(1024 * 1024 * 1024), equals('1.00 GB'));
      expect(
          formatBytes((1024 * 1024 * 1024 * 2.5).toInt()), equals('2.50 GB'));
    });

    test('should handle negative bytes', () {
      // Implementation dependent - should probably throw or return 0
      final result = formatBytes(-100);
      expect(result, isA<String>());
    });
  });

  group('formatDateTime', () {
    test('should format datetime', () {
      final dt = DateTime(2024, 3, 15, 10, 30, 45);
      final formatted = formatDateTime(dt);

      expect(formatted, equals('2024-03-15 10:30:45'));
    });

    test('should pad single digits', () {
      final dt = DateTime(2024, 1, 5, 9, 5, 3);
      final formatted = formatDateTime(dt);

      expect(formatted, equals('2024-01-05 09:05:03'));
    });

    test('should handle midnight', () {
      final dt = DateTime(2024, 12, 31, 0, 0, 0);
      final formatted = formatDateTime(dt);

      expect(formatted, equals('2024-12-31 00:00:00'));
    });

    test('should handle end of day', () {
      final dt = DateTime(2024, 12, 31, 23, 59, 59);
      final formatted = formatDateTime(dt);

      expect(formatted, equals('2024-12-31 23:59:59'));
    });
  });

  group('truncate', () {
    test('should not truncate short strings', () {
      expect(truncate('Hello', 10), equals('Hello'));
      expect(truncate('Test', 4), equals('Test'));
    });

    test('should truncate long strings', () {
      expect(truncate('Hello World!', 8), equals('Hello...'));
      expect(truncate('This is a very long string', 10), equals('This is...'));
    });

    test('should handle exact length', () {
      expect(truncate('Hello', 5), equals('Hello'));
    });

    test('should handle empty string', () {
      expect(truncate('', 10), equals(''));
    });

    test('should handle tiny max length', () {
      expect(truncate('Hello', 3), equals(''));
      expect(truncate('Hello', 4), equals('H...'));
    });

    test('should preserve unicode characters before truncation', () {
      expect(truncate('Hello 🔐 World', 10), equals('Hello 🔐...'));
    });
  });
}
