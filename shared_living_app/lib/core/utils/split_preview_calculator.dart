/// Client-side split preview calculator.
/// Rule: Client calculation is PREVIEW ONLY.
/// Server always computes equal splits; client never transmits computed shares for equal splits.
class SplitPreviewCalculator {
  /// Sorts member IDs numerically by stripping leading letter (e.g. 'M2' -> 2, 'M10' -> 10).
  /// Example: ['M2', 'M10', 'M1'] -> ['M1', 'M2', 'M10'].
  static List<String> sortMemberIds(List<String> memberIds) {
    final sorted = List<String>.from(memberIds);
    sorted.sort((a, b) {
      final aNum = int.tryParse(a.replaceAll(RegExp(r'^[^\d]+'), '')) ?? 0;
      final bNum = int.tryParse(b.replaceAll(RegExp(r'^[^\d]+'), '')) ?? 0;
      return aNum.compareTo(bNum);
    });
    return sorted;
  }

  /// Calculates equal split preview in integer paisas.
  /// Paisa remainder is distributed 1-by-1 in ascending numerical member ID order.
  /// Example: 100000 paisa across ['M01', 'M02', 'M03'] -> {'M01': 33334, 'M02': 33333, 'M03': 33333}
  static Map<String, int> previewEqualSplit({
    required int totalPaisa,
    required List<String> memberIds,
  }) {
    if (memberIds.isEmpty || totalPaisa <= 0) return {};

    final sortedMembers = sortMemberIds(memberIds);
    final count = sortedMembers.length;
    final baseShare = totalPaisa ~/ count;
    final remainder = totalPaisa % count;

    final result = <String, int>{};
    for (int i = 0; i < count; i++) {
      final extra = i < remainder ? 1 : 0;
      result[sortedMembers[i]] = baseShare + extra;
    }
    return result;
  }
}
