class Inspection {
  final int itemId;
  final String itemName;
  bool passed;
  String? note;
  final bool isRequired;

  Inspection(
      {required this.itemId,
      required this.itemName,
      this.passed = true,
      this.note,
      required this.isRequired});

  // Convert to ItemNoteRequest format for API
  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'passed': passed,
      'note': passed ? null : note,
      'isRequired': isRequired
    };
  }

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
        itemId: json['itemId'] ?? json['id'] ?? 0,
        itemName: json['itemName'] ?? json['name'] ?? '',
        passed: json['passed'] ?? true,
        note: json['note'],
        isRequired: json['isRequired']);
  }
}
