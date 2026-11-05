import 'package:flutter_test/flutter_test.dart';
import 'package:shared_living_app/core/utils/split_preview_calculator.dart';

void main() {
  group('SplitPreviewCalculator Tests', () {
    test('Sorts member IDs numerically (e.g. [M2, M10, M1] -> [M1, M2, M10])', () {
      final input = ['M2', 'M10', 'M1'];
      final sorted = SplitPreviewCalculator.sortMemberIds(input);
      expect(sorted, ['M1', 'M2', 'M10']);
    });

    test('Equal split preview allocates paisa remainder 1-by-1 in ascending order', () {
      // PKR 1,000.00 = 100000 paisa across 3 members
      final preview = SplitPreviewCalculator.previewEqualSplit(
        totalPaisa: 100000,
        memberIds: ['M03', 'M01', 'M02'],
      );

      // Must be numerically sorted: M01 receives extra paisa (+1), M02 and M03 receive base share
      expect(preview['M01'], 33334);
      expect(preview['M02'], 33333);
      expect(preview['M03'], 33333);

      final sum = preview.values.fold(0, (a, b) => a + b);
      expect(sum, 100000);
    });

    test('Equal split with 2 paisa remainder across 3 members', () {
      // 100001 paisa -> remainder = 2
      final preview = SplitPreviewCalculator.previewEqualSplit(
        totalPaisa: 100001,
        memberIds: ['M1', 'M2', 'M3'],
      );
      expect(preview['M1'], 33334);
      expect(preview['M2'], 33334);
      expect(preview['M3'], 33333);
      expect(preview.values.fold(0, (a, b) => a + b), 100001);
    });
  });
}
