import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/inspection.dart';
import 'inspection_item_card.dart';

class CategoryCard extends StatefulWidget {
  final Category category;
  final List<Inspection> inspections;
  final Map<int, bool> validationErrors;
  final Function(int itemId, bool passed, String? note) onInspectionChanged;

  const CategoryCard({
    Key? key,
    required this.category,
    required this.inspections,
    required this.validationErrors,
    required this.onInspectionChanged,
  }) : super(key: key);

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    // Calculate category stats
    int totalItems = widget.inspections.length;
    int failedItems = widget.inspections.where((i) => !i.passed).length;
    int itemsWithNotes = widget.inspections
        .where((i) => !i.passed && i.note != null && i.note!.isNotEmpty)
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: _isExpanded ? 1 : 0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.category,
                        color: Color(0xFF1E3A8A), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category.khmerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalItems items • $failedItems failed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (failedItems > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: itemsWithNotes == failedItems
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            itemsWithNotes == failedItems
                                ? Icons.check_circle
                                : Icons.warning,
                            size: 12,
                            color: itemsWithNotes == failedItems
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$itemsWithNotes/$failedItems',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: itemsWithNotes == failedItems
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF1E3A8A),
                  ),
                ],
              ),
            ),
          ),

          // Items
          if (_isExpanded)
            ...widget.inspections.asMap().entries.map((entry) {
              final index = entry.key;
              final inspection = entry.value;
              final isLast = index == widget.inspections.length - 1;

              return InspectionItemCard(
                inspection: inspection,
                hasError: widget.validationErrors[inspection.itemId] == true,
                onChanged: (passed, note) {
                  widget.onInspectionChanged(
                    inspection.itemId,
                    passed,
                    note,
                  );
                },
                showDivider: !isLast,
              );
            }).toList(),
        ],
      ),
    );
  }
}
