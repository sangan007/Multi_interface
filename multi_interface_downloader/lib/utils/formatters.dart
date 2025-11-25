import 'package:intl/intl.dart';

/// App-wide constants for easy localization/changes
class AppConstants {
  static const String appTitle = 'Multi-Interface Download Monitor';
  static const String statusReady = 'Ready';
  static const String statusDownloading = 'Downloading…';
  static const String statusComplete = 'Download Complete!';
  static const String statusMismatch = 'Complete (Size Mismatch)';
  static const String statusFailed = 'Download Failed';
  static const String statusStopped = 'Stopped';
  
  static const String msgStoppedByUser = '[Download stopped by user]';
  static const String msgSuccess = '✓ Download successful!';
  static const String msgMismatch = '✗ Warning: File size mismatch!';
}

/// Formats bytes into human readable string (KB, MB, GB)
String formatBytes(int bytes, [int decimals = 2]) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB"];
  var i = (bytes.toString().length - 1) ~/ 3; // rough estimate log10
  // Handle edge cases for small numbers or very large
  if (i >= suffixes.length) i = suffixes.length - 1;
  
  double value = bytes / (1 << (10 * i)); // binary division (1024)
  
  // Custom logic to match standard tools behavior
  if (i == 0) return "$bytes B";
  
  return "${value.toStringAsFixed(decimals)} ${suffixes[i]}";
}

/// Formats current timestamp for logs
String getCurrentTimestamp() {
  return DateFormat('HH:mm:ss').format(DateTime.now());
}