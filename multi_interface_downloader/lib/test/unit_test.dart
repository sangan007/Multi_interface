import 'package:flutter_test/flutter_test.dart';
import 'package:multi_interface_downloader/utils/formatters.dart';

void main() {
  group('Logic & Math Tests', () {
    test('Format bytes returns correct human readable strings', () {
      expect(formatBytes(500), '500 B');
      expect(formatBytes(1024), '1.00 KB');
      expect(formatBytes(1048576), '1.00 MB');
    });

    test('Midpoint calculation logic (simulation)', () {
      const int fileSize = 2000;
      final int midpoint = fileSize ~/ 2;
      final int p1End = midpoint - 1;
      final int p2Start = midpoint;
      final int p2End = fileSize - 1;

      expect(midpoint, 1000);
      expect(p1End, 999);
      expect(p2Start, 1000);
      // Ensure no overlap
      expect(p1End < p2Start, true);
      // Ensure coverage
      expect((p1End - 0 + 1) + (p2End - p2Start + 1), fileSize);
    });
    
    test('Odd file size calculation logic', () {
      const int fileSize = 11;
      final int midpoint = fileSize ~/ 2; // 5
      final int p1End = midpoint - 1; // 4 (0,1,2,3,4 = 5 bytes)
      final int p2Start = midpoint; // 5
      final int p2End = fileSize - 1; // 10 (5,6,7,8,9,10 = 6 bytes)
      
      expect(p1End, 4);
      expect(p2Start, 5);
      expect((p1End + 1) + (p2End - p2Start + 1), fileSize);
    });
  });
}