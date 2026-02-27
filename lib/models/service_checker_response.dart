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
  final List<ServiceCheckerItem> items;

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

  // Flatten items for UI display
  List<ChecklistItem> get flattenedItems {
    return items.expand((item) => item.inspectionItems).toList();
  }

  // Group items by category for UI display
  Map<CategoryDTO, List<ChecklistItem>> get itemsByCategory {
    final Map<CategoryDTO, List<ChecklistItem>> result = {};

    for (var item in items) {
      result[item.category] = item.inspectionItems;
    }

    return result;
  }

  factory ServiceChecker.fromJson(Map<String, dynamic> json) {
    print("📦 ===== PARSING SERVICE CHECKER =====");
    print("📦 JSON keys: ${json.keys}");

    // Parse items from the response
    List<ServiceCheckerItem> parsedItems = [];

    if (json.containsKey('items') && json['items'] != null) {
      try {
        final itemsList = json['items'] as List;
        print("📦 Found ${itemsList.length} items");

        parsedItems = itemsList.map((itemJson) {
          return ServiceCheckerItem.fromJson(itemJson as Map<String, dynamic>);
        }).toList();
      } catch (e) {
        print("❌ Error parsing items: $e");
      }
    } else {
      print("⚠️ No 'items' field in response");
    }

    return ServiceChecker(
      id: json['id'],
      licensePlate: json['licensePlate'] ?? 'Unknown',
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      totalItems: json['totalItems'] ?? parsedItems.length,
      itemNoteCount: json['itemNoteCount'] ?? 0,
      checkedCount: json['checkedCount'] ?? 0,
      notCheckedCount: json['notCheckedCount'] ?? 0,
      imagePath: json['imagePath'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      items: parsedItems,
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

class ServiceCheckerItem {
  final int id;
  final CategoryDTO category;
  final List<ServiceCheckerItemNote> notes;

  ServiceCheckerItem({
    required this.id,
    required this.category,
    required this.notes,
  });

  factory ServiceCheckerItem.fromJson(Map<String, dynamic> json) {
    return ServiceCheckerItem(
      id: json['id'] ?? 0,
      category: CategoryDTO.fromJson(json['category'] ?? {}),
      notes: json['notes'] != null
          ? (json['notes'] as List)
              .map((noteJson) => ServiceCheckerItemNote.fromJson(noteJson))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.toJson(),
      'notes': notes.map((note) => note.toJson()).toList(),
    };
  }

  // Helper method to get all inspection items from notes
  List<ChecklistItem> get inspectionItems {
    return notes.map((note) {
      return ChecklistItem(
        id: note.inspectionItem.id,
        name: note.inspectionItem.name,
        khmerName: note.inspectionItem.khmerName,
        englishName: note.inspectionItem.englishName,
        passed: note.passed,
        note: note.note,
        categoryId: category.id,
      );
    }).toList();
  }
}

class CategoryDTO {
  final int id;
  final String name;
  final String? khmerName;

  CategoryDTO({
    required this.id,
    required this.name,
    this.khmerName,
  });

  factory CategoryDTO.fromJson(Map<String, dynamic> json) {
    return CategoryDTO(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      khmerName: json['khmerName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'khmerName': khmerName,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryDTO && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class ServiceCheckerItemNote {
  final int id;
  final ItemDTO inspectionItem;
  final bool passed;
  final String? note;

  ServiceCheckerItemNote({
    required this.id,
    required this.inspectionItem,
    required this.passed,
    this.note,
  });

  factory ServiceCheckerItemNote.fromJson(Map<String, dynamic> json) {
    return ServiceCheckerItemNote(
      id: json['id'] ?? 0,
      inspectionItem: ItemDTO.fromJson(json['inspectionItem'] ?? {}),
      passed: json['passed'] ?? true,
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspectionItem': inspectionItem.toJson(),
      'passed': passed,
      'note': note,
    };
  }
}

class ItemDTO {
  final int id;
  final String name;
  final String? khmerName;
  final String? englishName;

  ItemDTO({
    required this.id,
    required this.name,
    this.khmerName,
    this.englishName,
  });

  factory ItemDTO.fromJson(Map<String, dynamic> json) {
    return ItemDTO(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      khmerName: json['khmerName'],
      englishName: json['englishName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'khmerName': khmerName,
      'englishName': englishName,
    };
  }
}

// Extended ChecklistItem for UI with additional fields
class ChecklistItem {
  final int id;
  final String name;
  final String? khmerName;
  final String? englishName;
  final bool passed;
  final String? note;
  final int? categoryId;

  ChecklistItem({
    required this.id,
    required this.name,
    this.khmerName,
    this.englishName,
    required this.passed,
    this.note,
    this.categoryId,
  });

  // Display name priority: khmerName > name
  String get displayName => khmerName ?? name;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['itemName'] ?? '',
      khmerName: json['khmerName'],
      englishName: json['englishName'],
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
      'englishName': englishName,
      'passed': passed,
      'note': note,
      'categoryId': categoryId,
    };
  }
}
