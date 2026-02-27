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

    // Debug print to verify data
    print('📁 Category: ${widget.category.khmerName} - ${widget.category.id}');
    print('   Total items: $totalItems');
    print('   Failed items: $failedItems');

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
          // Header - Always visible
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  // Category Icon - Always visible
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.category,
                      color: Color(0xFF1E3A8A),
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Category Name and Stats - Always visible
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Category Name
                        Text(
                          widget.category.khmerName.isNotEmpty
                              ? widget.category.khmerName
                              : 'Unnamed Category',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF1E3A8A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Stats Row
                        Row(
                          children: [
                            // Total items
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$totalItems items',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            if (failedItems > 0) ...[
                              const SizedBox(width: 6),
                              // Failed items
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: failedItems == itemsWithNotes
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      failedItems == itemsWithNotes
                                          ? Icons.check_circle
                                          : Icons.warning,
                                      size: 10,
                                      color: failedItems == itemsWithNotes
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '$failedItems failed',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: failedItems == itemsWithNotes
                                            ? Colors.green.shade700
                                            : Colors.orange.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Notes indicator (if any)
                  if (itemsWithNotes > 0) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.note,
                            size: 12,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$itemsWithNotes',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Expand/Collapse Icon
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xFF1E3A8A),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Items - Only visible when expanded
          if (_isExpanded && widget.inspections.isNotEmpty) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade200,
            ),
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
          ] else if (_isExpanded && widget.inspections.isEmpty) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade200,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox,
                      size: 32,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No items in this category',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
