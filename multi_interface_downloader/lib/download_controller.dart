import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'download_service_native.dart';
import 'utils/formatters.dart';

class DownloadState {
  final String status;
  final bool isDownloading;
  final List<String> logs;

  DownloadState({
    required this.status,
    required this.isDownloading,
    required this.logs,
  });

  DownloadState copyWith({
    String? status,
    bool? isDownloading,
    List<String>? logs,
  }) {
    return DownloadState(
      status: status ?? this.status,
      isDownloading: isDownloading ?? this.isDownloading,
      logs: logs ?? this.logs,
    );
  }
}

// Provider setup
final downloadControllerProvider = StateNotifierProvider<DownloadController, DownloadState>((ref) {
  // We use the NativeDownloadService here
  return DownloadController(NativeDownloadService());
});

class DownloadController extends StateNotifier<DownloadState> {
  final NativeDownloadService _service;
  StreamSubscription? _subscription;

  DownloadController(this._service)
      : super(DownloadState(
          status: AppConstants.statusReady,
          isDownloading: false,
          logs: [],
        )) {
    // Listen to events coming from Kotlin
    _subscription = _service.updates.listen((data) {
      final type = data['type'];
      final message = data['message'];

      if (type == 'log') {
        _addLog(message);
      } else if (type == 'status') {
        state = state.copyWith(status: message);
        
        // Handle logic state based on string status
        if (message == AppConstants.statusComplete) {
          state = state.copyWith(isDownloading: false);
          _addLog("✓ Download verified by native engine.");
        } else if (message == AppConstants.statusFailed || message == AppConstants.statusStopped) {
          state = state.copyWith(isDownloading: false);
        } else if (message == "Downloading...") {
          state = state.copyWith(isDownloading: true);
        }
      } else if (type == 'progress') {
        // Optional: You could parse this for a progress bar, 
        // but for now we log it to terminal as requested.
        // We only add it if it's different to avoid massive spam, 
        // but the native side throttles to 1sec anyway.
        _addLog(message);
      }
    });
  }

  void _addLog(String message) {
    final timestamp = getCurrentTimestamp();
    // Keep log buffer reasonable size if needed, but for now append all
    state = state.copyWith(logs: [...state.logs, "$timestamp $message"]);
  }

  Future<void> startDownload({
    required String url,
    required String iface1, // Note: Native engine auto-detects real ifaces now
    required String iface2,
    required String fileName,
  }) async {
    if (state.isDownloading) return;

    state = DownloadState(
      status: AppConstants.statusDownloading,
      isDownloading: true,
      logs: [],
    );

    _addLog("Bridge: Requesting Native Dual-Stack Download...");
    _addLog("Target: $url");

    try {
      await _service.startDownload(url, fileName);
    } catch (e) {
      _addLog("Bridge Error: $e");
      state = state.copyWith(status: AppConstants.statusFailed, isDownloading: false);
    }
  }

  void stopDownload() {
    _service.stopDownload();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}