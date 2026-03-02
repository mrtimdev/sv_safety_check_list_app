import 'package:intl/intl.dart';
import 'package:safety_check_list/providers/settings_provider.dart';

class ServiceChecker {
  final int? id;
  final String licensePlate;
  final String? licensePlateEstimated;
  final DateTime date;
  final int totalItems;
  final int itemNoteCount;
  final int checkedCount;
  final int notCheckedCount;
  final String? imagePath;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String status;
  final String? cancelReason;
  final DateTime? cancelledAt;
  final UserDTO? createdBy;
  final UserDTO? updatedBy;
  final UserDTO? cancelledBy;
  final List<ServiceCheckerItem> items;

  ServiceChecker({
    this.id,
    required this.licensePlate,
    this.licensePlateEstimated,
    required this.date,
    required this.totalItems,
    required this.itemNoteCount,
    required this.checkedCount,
    required this.notCheckedCount,
    this.imagePath,
    this.createdAt,
    this.updatedAt,
    required this.status,
    this.cancelReason,
    this.cancelledAt,
    this.createdBy,
    this.updatedBy,
    this.cancelledBy,
    required this.items,
  });

  String get formattedDate =>
      DateFormat('dd MMM yyyy', SettingsProvider.currentLocale.languageCode)
          .format(date);

  String get formattedTime =>
      DateFormat('hh:mm a', SettingsProvider.currentLocale.languageCode)
          .format(createdAt ?? date);

  String get createdAtFormattedTime => DateFormat(
          'dd MMM yyyy, hh:mm a', SettingsProvider.currentLocale.languageCode)
      .format(createdAt ?? date);

  String get cancelledAtFormattedTime => cancelledAt != null
      ? DateFormat('dd MMM yyyy, hh:mm a',
              SettingsProvider.currentLocale.languageCode)
          .format(cancelledAt!)
      : '';

  double get passRate {
    final total = checkedCount + notCheckedCount;
    if (total == 0) return 0;
    final rate = (checkedCount / total) * 100;
    return rate;
  }

  bool get isCancelled => status == 'CANCELLED';
  bool get isChecked => status == 'CHECKED';
  bool get isChecking => status == 'CHECKING';
  bool get isUnchecked => status == 'UNCHECKED';

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
      licensePlateEstimated: json['licensePlateEstimated'],
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      totalItems: json['totalItems'] ?? parsedItems.length,
      itemNoteCount: json['itemNoteCount'] ?? 0,
      checkedCount: json['checkedCount'] ?? 0,
      notCheckedCount: json['notCheckedCount'] ?? 0,
      imagePath: json['imagePath'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      status: json['status'] ?? 'CHECKING',
      cancelReason: json['cancelReason'],
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'])
          : null,
      createdBy: json['createdBy'] != null
          ? UserDTO.fromJson(json['createdBy'])
          : null,
      updatedBy: json['updatedBy'] != null
          ? UserDTO.fromJson(json['updatedBy'])
          : null,
      cancelledBy: json['cancelledBy'] != null
          ? UserDTO.fromJson(json['cancelledBy'])
          : null,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'licensePlate': licensePlate,
      'licensePlateEstimated': licensePlateEstimated,
      'date': date.toIso8601String(),
      'totalItems': totalItems,
      'itemNoteCount': itemNoteCount,
      'checkedCount': checkedCount,
      'notCheckedCount': notCheckedCount,
      'imagePath': imagePath,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'status': status,
      'cancelReason': cancelReason,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'createdBy': createdBy?.toJson(),
      'updatedBy': updatedBy?.toJson(),
      'cancelledBy': cancelledBy?.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

// New UserDTO class to match backend
class UserDTO {
  final int id;
  final String username;
  final String? email;
  final String? fullName;
  final String? role;

  UserDTO({
    required this.id,
    required this.username,
    this.email,
    this.fullName,
    this.role,
  });

  factory UserDTO.fromJson(Map<String, dynamic> json) {
    return UserDTO(
      id: json['id'] ?? 0,
      username: json['username'] ?? json['name'] ?? '',
      email: json['email'],
      fullName: json['fullName'] ?? json['fullname'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'role': role,
    };
  }

  String get displayName => fullName ?? username;
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
        passed: note.passed,
        note: note.note,
        categoryId: category.id,
        categoryName: category.name,
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

  ItemDTO({
    required this.id,
    required this.name,
    this.khmerName,
  });

  factory ItemDTO.fromJson(Map<String, dynamic> json) {
    return ItemDTO(
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
}

// Updated ChecklistItem for UI with category name
class ChecklistItem {
  final int id;
  final String name;
  final String? khmerName;
  final bool passed;
  final String? note;
  final int? categoryId;
  final String? categoryName;

  ChecklistItem({
    required this.id,
    required this.name,
    this.khmerName,
    required this.passed,
    this.note,
    this.categoryId,
    this.categoryName,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['itemName'] ?? '',
      khmerName: json['khmerName'],
      passed: json['passed'] ?? true,
      note: json['note'],
      categoryId: json['categoryId'],
      categoryName: json['categoryName'],
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
      'categoryName': categoryName,
    };
  }

  String get displayName => khmerName ?? name;
}
