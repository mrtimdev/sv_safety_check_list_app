import 'package:intl/intl.dart';

class ServiceChecker {
  final int? id;
  final String licensePlate;
  final DateTime date;
  final int totalItems;
  final int itemNoteCount;
  final int checkedCount;
  final int notCheckedCount;
  final String? imagePath;
  final DateTime? createdAt;
  final List<ChecklistItem> items;

  ServiceChecker({
    this.id,
    required this.licensePlate,
    required this.date,
    required this.totalItems,
    required this.itemNoteCount,
    required this.checkedCount,
    required this.notCheckedCount,
    this.imagePath,
    this.createdAt,
    required this.items,
  });

  // Computed properties
  String get formattedDate => DateFormat('dd MMM yyyy').format(date);
  String get formattedTime => DateFormat('HH:mm').format(date);

  double get passRate {
    if (totalItems == 0) return 0;
    return (checkedCount / totalItems) * 100;
  }

  factory ServiceChecker.fromJson(Map<String, dynamic> json) {
    print("📦 Parsing ServiceChecker from JSON: $json");

    return ServiceChecker(
      id: json['id'],
      licensePlate: json['licensePlate'] ?? 'Unknown',
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      totalItems: json['totalItems'] ?? 0,
      itemNoteCount: json['itemNoteCount'] ?? 0,
      checkedCount: json['checkedCount'] ?? 0,
      notCheckedCount: json['notCheckedCount'] ?? 0,
      imagePath: json['imagePath'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((itemJson) => ChecklistItem.fromJson(itemJson))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'licensePlate': licensePlate,
      'date': date.toIso8601String(),
      'totalItems': totalItems,
      'itemNoteCount': itemNoteCount,
      'checkedCount': checkedCount,
      'notCheckedCount': notCheckedCount,
      'imagePath': imagePath,
      'createdAt': createdAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class ChecklistItem {
  final int id;
  final String name;
  final String? khmerName;
  final bool passed;
  final String? note;
  final int? categoryId;

  ChecklistItem({
    required this.id,
    required this.name,
    this.khmerName,
    required this.passed,
    this.note,
    this.categoryId,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['itemName'] ?? '',
      khmerName: json['khmerName'],
      passed: json['passed'] ?? true,
      note: json['note'],
      categoryId: json['categoryId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'khmerName': khmerName,
      'passed': passed,
      'note': note,
      'categoryId': categoryId,
    };
  }
}
