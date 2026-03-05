class Category {
  final int id;
  final String khmerName;
  final String? englishName;
  final List<ChecklistItem> items;

  Category({
    required this.id,
    required this.khmerName,
    this.englishName,
    required this.items,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    print('Parsing category: $json');
    return Category(
      id: json['id'] ?? 0,
      khmerName: json['khmerName'] ?? json['name'] ?? '',
      englishName: json['englishName'],
      items: (json['items'] as List?)
              ?.map((item) => ChecklistItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'khmerName': khmerName,
      'englishName': englishName,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class ChecklistItem {
  final int id;
  final String khmerName;
  final String? englishName;
  final bool isRequired;

  ChecklistItem(
      {required this.id,
      required this.khmerName,
      this.englishName,
      required this.isRequired});

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
        id: json['id'] ?? 0,
        khmerName: json['khmerName'] ?? json['name'] ?? '',
        englishName: json['englishName'],
        isRequired: json['isRequired']);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'khmerName': khmerName,
      'englishName': englishName,
      'isRequired': isRequired
    };
  }
}
