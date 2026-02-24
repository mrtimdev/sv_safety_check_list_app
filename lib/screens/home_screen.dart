import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/service_checker.dart';
import '../services/api_service.dart';
import '../widgets/filter_chips.dart';
import '../widgets/loading_indicator.dart';
import 'checklist_form_screen.dart';
import 'checklist_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _hasMore = false;

  // Data
  List<ServiceChecker> _checklists = [];
  List<ServiceChecker> _filteredChecklists = [];

  // Filter states
  String _selectedFilter = 'all';
  String? _selectedDriverId;

  // UI states
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  // Modern Blue Color Palette
  static const Color primaryBlue = Color(0xFF1E40AF);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color accentBlue = Color(0xFF60A5FA);
  static const Color lightBlue = Color(0xFFDBEAFE);
  static const Color darkBlue = Color(0xFF1E3A8A);
  static const Color surfaceBlue = Color(0xFFF0F9FF);

  @override
  void initState() {
    super.initState();
    _loadChecklists();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadChecklists({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _apiService.getChecklists(
        page: _currentPage,
        limit: 20,
        dateFilter: _selectedFilter != 'all' ? _selectedFilter : null,
        driverId:
            _selectedDriverId != null ? int.parse(_selectedDriverId!) : null,
      );

      setState(() {
        if (refresh || _currentPage == 1) {
          _checklists = _apiService.parseChecklistsFromResponse(response);
        } else {
          _checklists.addAll(_apiService.parseChecklistsFromResponse(response));
        }

        _currentPage = response['currentPage'] + 1;
        _totalPages = response['totalPages'];
        _totalItems = response['totalItems'];
        _hasMore = response['hasMore'] ?? false;

        _applyLocalFilter();
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (mounted) {
        _showModernSnackBar('Error loading checklists: ${e.toString()}',
            isError: true);
      }
    }
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isError ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.red : Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? Colors.red.shade900 : Colors.green.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade50 : Colors.green.shade50,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        elevation: 0,
      ),
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _loadChecklists();
  }

  void _applyLocalFilter() {
    setState(() {
      _filteredChecklists = _checklists;
      _filteredChecklists.sort((a, b) => b.date.compareTo(a.date));
    });
  }

  Future<void> _onFilterChanged(String filter) async {
    setState(() {
      _selectedFilter = filter;
      _currentPage = 1;
      _isLoading = true;
      _checklists.clear();
    });

    await _loadChecklists(refresh: true);
  }

  Future<void> _refreshChecklists() async {
    setState(() {
      _currentPage = 1;
      _isLoading = true;
    });
    await _loadChecklists(refresh: true);
  }

  Future<void> _deleteChecklist(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade700),
            ),
            const SizedBox(width: 12),
            const Text('Delete Checklist'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this checklist? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('Delete',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteChecklist(id);
        setState(() {
          _checklists.removeWhere((c) => c.id == id);
          _applyLocalFilter();
        });
        if (mounted) {
          _showModernSnackBar('Checklist deleted successfully');
        }
      } catch (e) {
        if (mounted) {
          _showModernSnackBar('Error deleting checklist: ${e.toString()}',
              isError: true);
        }
      }
    }
  }

  Map<String, dynamic> _calculateStats() {
    int total = _checklists.length;
    int thisWeek = 0;
    double totalPassRate = 0;
    int totalItems = 0;
    int totalChecked = 0;

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    for (var checklist in _checklists) {
      if (checklist.date.isAfter(weekAgo)) {
        thisWeek++;
      }
      totalPassRate += checklist.passRate;
      totalItems += checklist.totalItems;
      totalChecked += checklist.checkedCount;
    }

    double avgPassRate = total > 0 ? totalPassRate / total : 0;
    double overallPassRate =
        totalItems > 0 ? (totalChecked / totalItems) * 100 : 0;

    return {
      'total': total,
      'thisWeek': thisWeek,
      'avgPassRate': avgPassRate,
      'overallPassRate': overallPassRate,
      'totalItems': totalItems,
      'totalChecked': totalChecked,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Safety Checklists',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: darkBlue,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: surfaceBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.search_rounded, size: 20),
              onPressed: _showSearchDialog,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: surfaceBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list_rounded, size: 20),
              onPressed: _showFilterDialog,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: surfaceBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _refreshChecklists,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshChecklists,
        color: primaryBlue,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Stats Dashboard
                  _buildStatsDashboard(stats),

                  // Filter Chips
                  FilterChips(
                    selectedFilter: _selectedFilter,
                    onFilterChanged: _onFilterChanged,
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),

            // Checklists List
            _isLoading && _checklists.isEmpty
                ? const SliverFillRemaining(
                    child: Center(
                        child:
                            LoadingIndicator(message: 'Loading checklists...')),
                  )
                : _errorMessage != null && _checklists.isEmpty
                    ? SliverFillRemaining(child: _buildErrorWidget())
                    : _checklists.isEmpty
                        ? SliverFillRemaining(child: _buildEmptyState())
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index == _filteredChecklists.length) {
                                    return _buildLoadingMoreIndicator();
                                  }
                                  return _buildModernChecklistCard(
                                      _filteredChecklists[index]);
                                },
                                childCount: _filteredChecklists.length +
                                    (_hasMore ? 1 : 0),
                              ),
                            ),
                          ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _navigateToForm(),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'New Check',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
          ),
          backgroundColor: primaryBlue,
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildStatsDashboard(Map<String, dynamic> stats) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [darkBlue, primaryBlue],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard Overview',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Safety Inspections',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildDashboardStat(
                  stats['total'].toString(),
                  'Total Checks',
                  Icons.assignment_turned_in_rounded,
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withOpacity(0.2),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: _buildDashboardStat(
                  stats['thisWeek'].toString(),
                  'This Week',
                  Icons.trending_up_rounded,
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withOpacity(0.2),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: _buildDashboardStat(
                  '${stats['overallPassRate'].toStringAsFixed(0)}%',
                  'Pass Rate',
                  Icons.verified_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModernChecklistCard(ServiceChecker checklist) {
    final passRate = checklist.passRate;
    final statusColor =
        passRate >= 80 ? primaryBlue : primaryBlue.withOpacity(0.3);
    final isExcellent = passRate >= 90;

    return Dismissible(
      key: Key('checklist_${checklist.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.delete_outline, color: Colors.red.shade700),
                ),
                const SizedBox(width: 12),
                const Text('Delete Checklist'),
              ],
            ),
            content:
                const Text('Are you sure you want to delete this checklist?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteChecklist(checklist.id!),
      child: GestureDetector(
        onTap: () => _navigateToDetail(checklist),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status Indicator with Progress Ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        value: passRate / 100,
                        strokeWidth: 4,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isExcellent
                            ? Icons.check_rounded
                            : Icons.directions_car_rounded,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              checklist.licensePlate,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: darkBlue,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${passRate.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            checklist.formattedDate,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time_rounded,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            checklist.formattedTime,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Item Summary Chips
                      Row(
                        children: [
                          _buildSummaryChip(
                            Icons.check_rounded,
                            '${checklist.checkedCount} Pass',
                            Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _buildSummaryChip(
                            Icons.close_rounded,
                            '${checklist.notCheckedCount} Fail',
                            Colors.red,
                          ),
                          if (checklist.itemNoteCount > 0) ...[
                            const SizedBox(width: 8),
                            _buildSummaryChip(
                              Icons.note_alt_rounded,
                              '${checklist.itemNoteCount} Note',
                              Colors.orange,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: CircularProgressIndicator(
          color: primaryBlue,
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 48,
                color: primaryBlue.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Checklists Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter != 'all'
                  ? 'No checklists found for selected filter'
                  : 'Start by creating your first safety inspection',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedFilter != 'all')
              ElevatedButton.icon(
                onPressed: () => _onFilterChanged('all'),
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Something Went Wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshChecklists,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showSearch(
      context: context,
      delegate: ChecklistSearchDelegate(_checklists),
    ).then((result) {
      if (result != null && result is ServiceChecker) {
        _navigateToDetail(result);
      }
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Filter Checklists',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a time period to filter your inspections',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            _buildFilterOption(
                'All Time', 'all', Icons.calendar_view_month_rounded),
            _buildFilterOption('Today', 'today', Icons.today_rounded),
            _buildFilterOption('Yesterday', 'yesterday', Icons.history_rounded),
            _buildFilterOption(
                'Last 7 Days', 'last7Days', Icons.date_range_rounded),
            _buildFilterOption(
                'Last 30 Days', 'last30Days', Icons.calendar_month_rounded),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryBlue.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? primaryBlue : Colors.grey.shade600,
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? darkBlue : Colors.grey.shade800,
        ),
      ),
      trailing: isSelected
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            )
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        Navigator.pop(context);
        _onFilterChanged(value);
      },
    );
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChecklistFormScreen()),
    );
    if (result == true) {
      _refreshChecklists();
    }
  }

  void _navigateToDetail(ServiceChecker checklist) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChecklistDetailScreen(checklist: checklist),
      ),
    );
    if (result == true) {
      _refreshChecklists();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

// Modern Search Delegate
class ChecklistSearchDelegate extends SearchDelegate<ServiceChecker?> {
  final List<ServiceChecker> checklists;

  ChecklistSearchDelegate(this.checklists);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _HomeScreenState.darkBlue),
        titleTextStyle: const TextStyle(
          color: _HomeScreenState.darkBlue,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.grey.shade400),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(_getResults());
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(_getResults());
  }

  List<ServiceChecker> _getResults() {
    if (query.isEmpty) return checklists;
    return checklists
        .where((checklist) =>
            checklist.licensePlate.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Widget _buildSearchResults(List<ServiceChecker> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Try searching with a different license plate',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final checklist = results[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _HomeScreenState.surfaceBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: _HomeScreenState.primaryBlue,
              ),
            ),
            title: Text(
              checklist.licensePlate,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _HomeScreenState.darkBlue,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                DateFormat('dd MMM yyyy • HH:mm').format(checklist.date),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: checklist.passRate >= 80
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${checklist.passRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  color:
                      checklist.passRate >= 80 ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            onTap: () => close(context, checklist),
          ),
        );
      },
    );
  }
}
