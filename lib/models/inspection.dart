class Inspection {
  final int itemId;
  final String itemName;
  bool? passed;
  String? note;
  final bool isRequired;

  Inspection(
      {required this.itemId,
      required this.itemName,
      this.passed,
      this.note,
      required this.isRequired});

  // Convert to ItemNoteRequest format for API
  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'passed': passed,
      'note': note,
      'isRequired': isRequired
    };
  }

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
        itemId: json['itemId'] ?? json['id'] ?? 0,
        itemName: json['itemName'] ?? json['name'] ?? '',
        passed: json['passed'] ?? null,
        note: json['note'],
        isRequired: json['isRequired']);
  }

  bool get isEvaluated => passed != null;
  bool get isPassed => passed == true;
  bool get isFailed => passed == false;
}
