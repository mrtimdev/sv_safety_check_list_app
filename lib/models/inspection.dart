class Inspection {
  final int itemId;
  final String itemName;
  bool passed;
  String? note;

  Inspection({
    required this.itemId,
    required this.itemName,
    this.passed = true,
    this.note,
  });

  // Convert to ItemNoteRequest format for API
  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'passed': passed,
      'note': passed ? null : note, // Only send note if failed
    };
  }

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      itemId: json['itemId'] ?? json['id'] ?? 0,
      itemName: json['itemName'] ?? json['name'] ?? '',
      passed: json['passed'] ?? true,
      note: json['note'],
    );
  }
}
