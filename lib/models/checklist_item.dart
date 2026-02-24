class ChecklistItem {
  final int id;
  final String khmerName;
  final String? englishName;

  ChecklistItem({required this.id, required this.khmerName, this.englishName});

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'],
      khmerName: json['khmerName'] ?? json['name'] ?? '',
      englishName: json['englishName'],
    );
  }
}
