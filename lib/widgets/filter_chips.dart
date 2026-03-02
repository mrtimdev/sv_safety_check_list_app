import 'package:flutter/material.dart';

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
    return Container(
      width: double.infinity, // Full width
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All Time', 'all'),
            const SizedBox(width: 12),
            _buildFilterChip('Today', 'today'),
            const SizedBox(width: 12),
            _buildFilterChip('Yesterday', 'yesterday'),
            const SizedBox(width: 12),
            _buildFilterChip('Last 7 Days', 'last7Days'),
            const SizedBox(width: 12),
            _buildFilterChip('Last 30 Days', 'last30Days'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.grey.shade700,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onFilterChanged(value);
        }
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF1E3A8A), // Using your primary color
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      elevation: isSelected ? 2 : 0,
      shadowColor: const Color(0xFF1E3A8A).withOpacity(0.3),
    );
  }
}
