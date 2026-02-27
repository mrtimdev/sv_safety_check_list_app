import 'package:flutter/material.dart';
import '../models/inspection.dart';

class InspectionItemCard extends StatefulWidget {
  final Inspection inspection;
  final bool hasError;
  final Function(bool passed, String? note) onChanged;
  final bool showDivider;

  const InspectionItemCard({
    Key? key,
    required this.inspection,
    this.hasError = false,
    required this.onChanged,
    this.showDivider = true,
  }) : super(key: key);

  @override
  State<InspectionItemCard> createState() => _InspectionItemCardState();
}

class _InspectionItemCardState extends State<InspectionItemCard> {
  late bool _passed;
  late TextEditingController _noteController;
  late FocusNode _noteFocusNode;

  @override
  void initState() {
    super.initState();
    _passed = widget.inspection.passed;
    _noteController = TextEditingController(text: widget.inspection.note);
    _noteFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(InspectionItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inspection.passed != widget.inspection.passed) {
      setState(() {
        _passed = widget.inspection.passed;
      });
    }
    if (oldWidget.inspection.note != widget.inspection.note) {
      _noteController.text = widget.inspection.note ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _passed ? null : (widget.hasError ? Colors.red.shade50 : null),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status icon
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      child: Icon(
                        _passed ? Icons.check_circle_outline : Icons.close,
                        size: 18,
                        color: _passed ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Item name and status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.inspection.itemName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _passed
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade900,
                              decoration: _passed ? null : TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildStatusChip('មាន', true),
                              const SizedBox(width: 8),
                              _buildStatusChip('មិនមាន', false),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Note field for failed items
                if (!_passed) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      // border: Border.all(
                      //   color:
                      //       widget.hasError ? Colors.red : Colors.grey.shade300,
                      //   width: widget.hasError ? 1.5 : 1,
                      // ),
                    ),
                    child: TextField(
                      controller: _noteController,
                      focusNode: _noteFocusNode,
                      decoration: InputDecoration(
                        hintText: 'បញ្ចូលមូលហេតុ...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        prefixIcon: const Icon(Icons.note,
                            size: 16, color: Colors.orange),
                        suffixIcon: _noteController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _noteController.clear();
                                  widget.onChanged(_passed, null);
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 2,
                      minLines: 1,
                      onChanged: (value) {
                        widget.onChanged(_passed, value);
                      },
                      onSubmitted: (value) {
                        widget.onChanged(_passed, value);
                      },
                    ),
                  ),
                  if (widget.hasError) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(width: 32),
                        Icon(Icons.warning_amber,
                            size: 12, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'សូមផ្តល់ហេតុផលខ្លះផងសម្រាប់ការត្រួតពិនិត្យនេះ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (widget.showDivider)
            Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: Colors.grey.shade200,
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, bool value) {
    final isSelected = _passed == value;

    return GestureDetector(
      onTap: () {
        if (_passed != value) {
          setState(() {
            _passed = value;

            // If switching to passed, clear note requirement
            if (value) {
              _noteController.clear();
              widget.onChanged(true, null);
            } else {
              // If switching to failed, focus note field
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _noteFocusNode.requestFocus();
              });
              widget.onChanged(false, _noteController.text);
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (value
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          // border: Border.all(
          //   color: isSelected
          //       ? (value ? Colors.green : Colors.red)
          //       : Colors.grey.shade300,
          //   width: isSelected ? 1.5 : 1,
          // ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (value ? Colors.green : Colors.red)
                : Colors.grey.shade600,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }
}
