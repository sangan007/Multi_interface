import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'download_service.dart';
import '../utils/formatters.dart';

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

// -- Provider --
final downloadControllerProvider = StateNotifierProvider<DownloadController, DownloadState>((ref) {
  return DownloadController(DownloadService());
});

// -- Controller --
class DownloadController extends StateNotifier<DownloadState> {
  final DownloadService _service;
  CancelToken? _cancelToken;
  Timer? _progressTimer;
  
  // Track file handles for progress polling
  File? _part1File;
  File? _part2File;
  int _part1ExpectedSize = 0;
  int _part2ExpectedSize = 0;
  String _iface1 = "";
  String _iface2 = "";

  DownloadController(this._service)
      : super(DownloadState(
          status: AppConstants.statusReady,
          isDownloading: false,
          logs: [],
        ));

  void addLog(String message) {
    final timestamp = getCurrentTimestamp();
    // Recreating list to trigger state update, avoiding mutation
    state = state.copyWith(logs: [...state.logs, "$timestamp $message"]);
  }

  void _setStatus(String status) {
    state = state.copyWith(status: status);
  }

  /// Validates inputs and starts the download workflow
  Future<void> startDownload({
    required String url,
    required String iface1,
    required String iface2,
    required String fileName,
  }) async {
    if (state.isDownloading) return;

    // 1. Reset State
    _cancelToken = CancelToken();
    state = DownloadState(
      status: AppConstants.statusDownloading,
      isDownloading: true,
      logs: [],
    );
    _iface1 = iface1.isEmpty ? "IF1" : iface1;
    _iface2 = iface2.isEmpty ? "IF2" : iface2;
    
    addLog("Initializing download for: $url");

    try {
      // 2. Size Detection
      addLog("Probing file size...");
      final int totalSize = await _service.getFileSize(url);
      addLog("File size detected: $totalSize bytes (${formatBytes(totalSize)})");

      // 3. Range Computation
      final int midpoint = totalSize ~/ 2;
      final int p1Start = 0;
      final int p1End = midpoint - 1;
      final int p2Start = midpoint;
      final int p2End = totalSize - 1;

      _part1ExpectedSize = (p1End - p1Start) + 1;
      _part2ExpectedSize = (p2End - p2Start) + 1;

      addLog("[$_iface1] Assigned Range: bytes=$p1Start-$p1End ($_part1ExpectedSize bytes)");
      addLog("[$_iface2] Assigned Range: bytes=$p2Start-$p2End ($_part2ExpectedSize bytes)");

      // 4. Prepare Files
      _part1File = await _service.getTempFile("part1.tmp");
      _part2File = await _service.getTempFile("part2.tmp");
    
      if (_part1File!.existsSync()) _part1File!.deleteSync();
      if (_part2File!.existsSync()) _part2File!.deleteSync();

      // 5. Start Progress Polling
      _startProgressTimer();

      // 6. Execute Parallel Downloads
      addLog("Starting parallel streams...");
      await Future.wait([
        _service.downloadChunk(
          url: url,
          start: p1Start,
          end: p1End,
          targetFile: _part1File!,
          cancelToken: _cancelToken!,
          onLog: addLog,
          interfaceLabel: _iface1,
        ),
        _service.downloadChunk(
          url: url,
          start: p2Start,
          end: p2End,
          targetFile: _part2File!,
          cancelToken: _cancelToken!,
          onLog: addLog,
          interfaceLabel: _iface2,
        ),
      ]);

      // 7. Completion & Merging
      _stopProgressTimer(); 
      _setStatus("Merging...");
      addLog("Streams complete. Merging parts...");

      final outputFile = await _service.getOutputFile(fileName);
      if (outputFile.existsSync()) outputFile.deleteSync();

      await _service.mergeFiles(_part1File!, _part2File!, outputFile);

      // 8. Validation
      final actualSize = outputFile.lengthSync();
      addLog("Final file created at: ${outputFile.path}");
      addLog("Final Size: $actualSize bytes. Expected: $totalSize bytes.");

      if (actualSize == totalSize) {
        addLog(AppConstants.msgSuccess);
        _setStatus(AppConstants.statusComplete);
      } else {
        addLog(AppConstants.msgMismatch);
        _setStatus(AppConstants.statusMismatch);
      }

    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) {
        addLog(AppConstants.msgStoppedByUser);
        _setStatus(AppConstants.statusStopped);
      } else {
        addLog("Error: $e");
        _setStatus(AppConstants.statusFailed);
      }
    } finally {
      _stopProgressTimer();
      state = state.copyWith(isDownloading: false);
      _cancelToken = null;
    }
  }

  void stopDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel();
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_part1File == null || _part2File == null) return;

      int s1 = 0;
      int s2 = 0;
      
      if (_part1File!.existsSync()) s1 = _part1File!.lengthSync();
      if (_part2File!.existsSync()) s2 = _part2File!.lengthSync();

      double p1Pct = _part1ExpectedSize > 0 ? (s1 / _part1ExpectedSize) * 100 : 0;
      double p2Pct = _part2ExpectedSize > 0 ? (s2 / _part2ExpectedSize) * 100 : 0;

      addLog("[$_iface1: ${p1Pct.toStringAsFixed(1)}% - ${formatBytes(s1)}] [$_iface2: ${p2Pct.toStringAsFixed(1)}% - ${formatBytes(s2)}]");
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }
}