import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
// import '../utils/formatters.dart';

class ContentLengthMissingException implements Exception {
  final String message;
  ContentLengthMissingException(this.message);
  @override
  String toString() => message;
}

class DownloadService {
  final Dio _dio = Dio();
  
 
  static const int _maxRetries = 2;
  
  Future<int> getFileSize(String url) async {
    try {
      final response = await _dio.head(url);
      final len = _parseContentLength(response.headers);
      if (len != null) return len;

      final rangeResponse = await _dio.get(
        url,
        options: Options(headers: {'Range': 'bytes=0-0'}),
      );
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
        await Future.delayed(Duration(seconds: 1 * retries)); 
      }
    }
  }

  Future<void> mergeFiles(File part1, File part2, File output) async {
    // Ensure output directory exists
    if (!output.parent.existsSync()) {
      output.parent.createSync(recursive: true);
    }


    final sink = output.openWrite();
    
    try {
      // Pipe 1
      await sink.addStream(part1.openRead());
      // Pipe  2
      await sink.addStream(part2.openRead());
    } finally {
      await sink.close();
    }
  }
  String sanitizeFilename(String input) {
    return p.basename(input); 
  }

  Future<File> getTempFile(String name) async {
    final dir = await getTemporaryDirectory();
    return File(p.join(dir.path, name));
  }

  Future<File> getOutputFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, sanitizeFilename(filename)));
  }
}