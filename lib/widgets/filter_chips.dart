import 'package:flutter/material.dart';
import 'package:safety_check_list/l10n/app_localizations.dart';

class FilterChips extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;

  const FilterChips({
    Key? key,
    required this.selectedFilter,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final filters = [
      {'label': t.allTime, 'value': 'all'},
      {'label': t.today, 'value': 'today'},
      {'label': t.yesterday, 'value': 'yesterday'},
      {'label': t.last7Days, 'value': 'last7Days'},
      {'label': t.last30Days, 'value': 'last30Days'},
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter['value'];

          return _buildFilterChip(
            filter['label']!,
            filter['value']!,
            isSelected,
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onFilterChanged(value);
        }
      },
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF1E3A8A),
      checkmarkColor: Colors.white,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      elevation: 0,
      showCheckmark: false,
    );
  }
}
