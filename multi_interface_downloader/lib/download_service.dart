import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
// import '../utils/formatters.dart';

/// Exception thrown when file size cannot be determined
class ContentLengthMissingException implements Exception {
  final String message;
  ContentLengthMissingException(this.message);
  @override
  String toString() => message;
}

/// Handles the core business logic of splitting, downloading, and merging files.
class DownloadService {
  final Dio _dio = Dio();
  
  // Configuration
  static const int _maxRetries = 2;
  
  /// Performs a HEAD request to get file size
  Future<int> getFileSize(String url) async {
    try {
      // Try HEAD first
      final response = await _dio.head(url);
      final len = _parseContentLength(response.headers);
      if (len != null) return len;

      // Fallback to GET range 0-0
      final rangeResponse = await _dio.get(
        url,
        options: Options(headers: {'Range': 'bytes=0-0'}),
      );
      // Content-Range: bytes 0-0/12345
      final contentRange = rangeResponse.headers.value('content-range');
      if (contentRange != null) {
        final parts = contentRange.split('/');
        if (parts.length == 2) {
          return int.parse(parts[1]);
        }
      }
      throw ContentLengthMissingException("Server did not report file size.");
    } catch (e) {
      if (e is ContentLengthMissingException) rethrow;
      throw ContentLengthMissingException("Failed to probe URL: ${e.toString()}");
    }
  }

  int? _parseContentLength(Headers headers) {
    final list = headers['content-length'];
    if (list != null && list.isNotEmpty) {
      return int.tryParse(list.first);
    }
    return null;
  }

  /// Downloads a specific chunk of the file with retry logic
  Future<void> downloadChunk({
    required String url,
    required int start,
    required int end,
    required File targetFile,
    required CancelToken cancelToken,
    required Function(String msg) onLog,
    required String interfaceLabel,
  }) async {
    int retries = 0;
    while (retries <= _maxRetries) {
      try {
        if (cancelToken.isCancelled) throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.cancel);

        await _dio.download(
          url,
          targetFile.path,
          cancelToken: cancelToken,
          deleteOnError: false, // We handle cleanup manually usually
          options: Options(
            headers: {'Range': 'bytes=$start-$end'},
            responseType: ResponseType.stream,
          ),
          onReceiveProgress: (count, total) {
            // Optional: verbose logging per chunk could go here, 
            // but we use the main poller in the controller to avoid UI flooding.
          },
        );
        onLog("[$interfaceLabel] Chunk download complete.");
        return; // Success
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) {
          rethrow;
        }
        retries++;
        onLog("[$interfaceLabel] Error: ${e.toString()}. Retry $retries/$_maxRetries...");
        if (retries > _maxRetries) rethrow;
        // Exponential backoff
        await Future.delayed(Duration(seconds: 1 * retries)); 
      }
    }
  }

  /// Merges two temporary files into the final output file efficiently
  Future<void> mergeFiles(File part1, File part2, File output) async {
    // Ensure output directory exists
    if (!output.parent.existsSync()) {
      output.parent.createSync(recursive: true);
    }

    // Open output stream
    final sink = output.openWrite();
    
    try {
      // Pipe part 1
      await sink.addStream(part1.openRead());
      // Pipe part 2
      await sink.addStream(part2.openRead());
    } finally {
      await sink.close();
    }
  }

  /// Sanitizes output filename to prevent directory traversal
  String sanitizeFilename(String input) {
    return p.basename(input); 
  }

  /// Gets a temporary file path
  Future<File> getTempFile(String name) async {
    final dir = await getTemporaryDirectory();
    return File(p.join(dir.path, name));
  }

  /// Gets the final documents directory file
  Future<File> getOutputFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, sanitizeFilename(filename)));
  }
}