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
  late bool? _passed;
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
    final bool isEvaluated = _passed != null;
    final bool isPassed = _passed == true;
    final bool isFailed = _passed == false;

    return Container(
      color: isFailed ? (widget.hasError ? Colors.red.shade50 : null) : null,
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
                    // Status icon - show different icon for unevaluated
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      child: Icon(
                        !isEvaluated
                            ? Icons.help_outline
                            : (isPassed
                                ? Icons.check_circle_outline
                                : Icons.close),
                        size: 18,
                        color: !isEvaluated
                            ? Colors.grey
                            : (isPassed ? Colors.green : Colors.red),
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
                              color: !isEvaluated
                                  ? Colors.grey.shade500
                                  : (isPassed
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade900),
                            ),
                          ),
                          if (widget.inspection.isRequired) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'លក្ខខណ្ឌនេះត្រូវតែមាន',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepOrangeAccent),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildStatusChip('ត្រឹមត្រូវ', true),
                              const SizedBox(width: 8),
                              _buildStatusChip('មិនត្រឹមត្រូវ', false),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Note field for failed items
                if (isFailed) ...[
                  const SizedBox(height: 16),
                  Container(
                    // decoration: BoxDecoration(
                    //   color: Colors.white,
                    //   borderRadius: BorderRadius.circular(10),
                    //   border: widget.hasError
                    //       ? Border.all(color: Colors.red.shade300)
                    //       : null,
                    // ),
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
                                  widget.onChanged(false, null);
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
                        widget.onChanged(false, value);
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
                        Expanded(
                          child: Text(
                            'សូមផ្តល់ហេតុផលសម្រាប់ការត្រួតពិនិត្យនេះ',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                // Show hint for unevaluated items
                // if (!isEvaluated) ...[
                //   const SizedBox(height: 8),
                //   Container(
                //     padding:
                //         const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                //     decoration: BoxDecoration(
                //       color: Colors.grey.shade100,
                //       borderRadius: BorderRadius.circular(8),
                //     ),
                //     child: Row(
                //       children: [
                //         Icon(Icons.info_outline,
                //             size: 14, color: Colors.grey.shade600),
                //         const SizedBox(width: 6),
                //         Expanded(
                //           child: Text(
                //             widget.inspection.isRequired
                //                 ? 'សូមជ្រើសរើស ត្រឹមត្រូវ ឬ មិនត្រឹមត្រូវ (តម្រូវ)'
                //                 : 'សូមជ្រើសរើស ត្រឹមត្រូវ ឬ មិនត្រឹមត្រូវ',
                //             style: TextStyle(
                //               fontSize: 11,
                //               color: Colors.grey.shade600,
                //               fontStyle: FontStyle.italic,
                //             ),
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
                // ],
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
        setState(() {
          _passed = value;

          if (value) {
            // User selected "Yes/Passed"
            _noteController.clear();
            widget.onChanged(true, null);
          } else {
            // User selected "No/Failed"
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _noteFocusNode.requestFocus();
            });
            widget.onChanged(false, _noteController.text);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (value
                  ? Colors.green.withOpacity(0.15)
                  : Colors.red.withOpacity(0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (value ? Colors.green : Colors.red)
                : (_passed == null
                    ? Colors.grey.shade300
                    : Colors.grey.shade400),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (value ? Colors.green : Colors.red).withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? (value ? Icons.check_circle : Icons.cancel)
                  : (value
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined),
              size: 16,
              color: isSelected
                  ? (value ? Colors.green : Colors.red)
                  : (_passed == null
                      ? Colors.grey.shade600
                      : Colors.grey.shade400),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (value ? Colors.green : Colors.red)
                    : (_passed == null
                        ? Colors.grey.shade600
                        : Colors.grey.shade400),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
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
