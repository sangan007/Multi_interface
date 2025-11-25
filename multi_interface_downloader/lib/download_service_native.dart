import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class NativeDownloadService {
  static const MethodChannel _methodChannel = MethodChannel('com.example.downloader/method');
  static const EventChannel _eventChannel = EventChannel('com.example.downloader/events');

  // Stream controller to broadcast native events to our Controller
  final StreamController<Map<String, dynamic>> _controller = StreamController.broadcast();

  NativeDownloadService() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final type = event['type'] as String?;
        final msg = event['message'] as String?;
        if (type != null && msg != null) {
          _controller.add({'type': type, 'message': msg});
        }
      }
    }, onError: (error) {
      _controller.add({'type': 'log', 'message': 'Native Bridge Error: $error'});
    });
  }

  Stream<Map<String, dynamic>> get updates => _controller.stream;

  Future<void> startDownload(String url, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final String savePath = p.join(dir.path, fileName);
    
    // Ensure we delete old one before starting
    final file = File(savePath);
    if(file.existsSync()) file.deleteSync();

    try {
      await _methodChannel.invokeMethod('startNativeDownload', {
        'url': url,
        'filePath': savePath,
      });
    } on PlatformException catch (e) {
      throw Exception("Failed to start native download: ${e.message}");
    }
  }

  Future<void> stopDownload() async {
    try {
      await _methodChannel.invokeMethod('stopNativeDownload');
    } catch (e) {
      // Ignore
    }
  }
}