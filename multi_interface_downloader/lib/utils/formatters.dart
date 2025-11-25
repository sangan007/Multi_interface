import 'package:intl/intl.dart';

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

String formatBytes(int bytes, [int decimals = 2]) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB"];
  var i = (bytes.toString().length - 1) ~/ 3; 
  if (i >= suffixes.length) i = suffixes.length - 1;
  
  double value = bytes / (1 << (10 * i)); 

  if (i == 0) return "$bytes B";
  
  return "${value.toStringAsFixed(decimals)} ${suffixes[i]}";
}

String getCurrentTimestamp() {
  return DateFormat('HH:mm:ss').format(DateTime.now());
}