import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:safety_check_list/l10n/app_localizations.dart';
import 'package:safety_check_list/models/device_info.dart';
import 'package:safety_check_list/models/service_checker.dart';
import 'package:safety_check_list/providers/settings_provider.dart';
// import 'package:safety_check_list/models/service_checker_request.dart';

import '../services/api_service.dart';
import '../services/secure_storage.dart';
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

  // View mode
  bool _isGridView = false;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _hasMore = false;

  // Data
  List<ServiceChecker> _checklists = [];
  List<ServiceChecker> _filteredChecklists = [];

  // Filter states
  String _selectedFilter = 'today';
  String? _selectedDriverId;

  // UI states
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  DeviceInfo? _deviceInfo;
  bool _loadingDeviceInfo = true;

  // User data
  Map<String, dynamic>? _userData;
  bool _initialLoadDone = false;

  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  // Modern Blue Color Palette
  static const Color primaryBlue = Color(0xFF1E40AF);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color accentBlue = Color(0xFF60A5FA);
  static const Color lightBlue = Color(0xFFDBEAFE);
  static const Color darkBlue = Color(0xFF1E3A8A);
  static const Color surfaceBlue = Color(0xFFF0F9FF);

  // Pass rate color ranges
  Color _getPassRateColor(double passRate) {
    if (passRate >= 90) {
      return Colors.green;
    } else if (passRate >= 75) {
      return Colors.lightGreen;
    } else if (passRate >= 50) {
      return Colors.orange;
    } else if (passRate >= 25) {
      return Colors.deepOrange;
    } else {
      return Colors.red;
    }
  }

  Color _getPassRateBackgroundColor(double passRate) {
    if (passRate >= 90) {
      return Colors.green.withOpacity(0.1);
    } else if (passRate >= 75) {
      return Colors.lightGreen.withOpacity(0.1);
    } else if (passRate >= 50) {
      return Colors.orange.withOpacity(0.1);
    } else if (passRate >= 25) {
      return Colors.deepOrange.withOpacity(0.1);
    } else {
      return Colors.red.withOpacity(0.1);
    }
  }

  IconData _getPassRateIcon(double passRate) {
    if (passRate >= 90) {
      return Icons.checklist_outlined; // Excellent
    } else if (passRate >= 75) {
      return Icons.thumb_up_rounded; // Good
    } else if (passRate >= 50) {
      return Icons.warning_amber_rounded; // Average
    } else if (passRate >= 25) {
      return Icons.error_outline_rounded; // Poor
    } else {
      return Icons.dangerous_rounded; // Critical
    }
  }

  String _getPassRateLabel(double passRate) {
    if (passRate >= 90) return 'ល្អឥតខ្ចោះ';
    if (passRate >= 75) return 'ល្អ';
    if (passRate >= 50) return 'មធ្យម';
    if (passRate >= 25) return 'ខ្សោយ';
    return 'គ្រោះថ្នាក់';
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDeviceInfo().then((_) {
      _loadChecklists();
    });
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadUserData() async {
    final userData = await SecureStorage.getUser();
    setState(() {
      _userData = userData;
    });
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = await DeviceInfo.getDeviceInfo();
      setState(() {
        _deviceInfo = deviceInfo;
        _loadingDeviceInfo = false;
      });
      print('📱 Device info loaded: ${deviceInfo.toJson()}');
    } catch (e) {
      print('❌ Error loading device info: $e');
      setState(() {
        _loadingDeviceInfo = false;
      });
    }
  }

  Future<void> _loadChecklists({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _isLoading = true;
        _errorMessage = null;
        _checklists.clear();
        _filteredChecklists.clear();
      });
    } else if (!refresh && !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      print('🔄 Loading checklists - Page: $_currentPage, Refresh: $refresh');

      final response = await _apiService.getChecklists(
        page: _currentPage,
        limit: 50,
        dateFilter: _selectedFilter != 'all' ? _selectedFilter : null,
        context: context,
      );

      setState(() {
        final newChecklists = _apiService.parseChecklistsFromResponse(response);

        if (refresh || _currentPage == 1) {
          _checklists = newChecklists;
          print('✅ Loaded ${newChecklists.length} items (fresh load)');
        } else {
          _checklists.addAll(newChecklists);
          print(
              '✅ Added ${newChecklists.length} items, total now: ${_checklists.length}');
        }

        _totalPages = response['totalPages'] ?? 1;
        _totalItems = response['totalItems'] ?? 0;
        _hasMore = response['hasMore'] ?? false;

        if (newChecklists.isNotEmpty) {
          _currentPage++;
          print('📄 Next page will be: $_currentPage');
        }

        _applyLocalFilter();
        _isLoading = false;
        _isLoadingMore = false;
        _initialLoadDone = true;
      });
    } catch (e) {
      print('❌ Error loading checklists: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (mounted && e.toString() != 'SESSION_EXPIRED') {
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
        _hasMore &&
        !_isLoading &&
        _initialLoadDone) {
      print('📱 Scrolled to bottom, loading more...');
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) {
      return;
    }
    await _loadChecklists(refresh: false);
  }

  Future<void> _refreshChecklists() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _isLoading = true;
    });
    await _loadChecklists(refresh: true);
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
      _hasMore = true;
      _isLoading = true;
      _checklists.clear();
      _filteredChecklists.clear();
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

    // Count by status
    int excellent = 0;
    int good = 0;
    int average = 0;
    int poor = 0;
    int critical = 0;

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    for (var checklist in _checklists) {
      // Count checklists for this week
      if (checklist.date.isAfter(weekAgo)) {
        thisWeek++;
      }

      // Sum individual checklist pass rates for average
      totalPassRate += checklist.passRate;

      // Sum total items and checked items for overall pass rate
      totalItems += checklist.totalItems;
      totalChecked += checklist.checkedCount;

      // Count by status
      if (checklist.passRate >= 90) {
        excellent++;
      } else if (checklist.passRate >= 75) {
        good++;
      } else if (checklist.passRate >= 50) {
        average++;
      } else if (checklist.passRate >= 25) {
        poor++;
      } else {
        critical++;
      }
    }

    // Average pass rate across all checklists
    double avgPassRate = total > 0 ? totalPassRate / total : 0;

    return {
      'total': total,
      'thisWeek': thisWeek,
      'avgPassRate': avgPassRate,
      'totalItems': totalItems,
      'totalChecked': totalChecked,
      'excellent': excellent,
      'good': good,
      'average': average,
      'poor': poor,
      'critical': critical,
    };
  }

  Future<void> _logout() async {
    try {
      final token = await SecureStorage.getToken();
      if (token != null) {
        await _apiService.logout(token);
      }
    } catch (e) {
      print('Logout error: $e');
    } finally {
      await SecureStorage.clearAll(); // Clear all stored data

      if (mounted) {
        // Show logout message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: darkBlue, size: 16),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'បានចាកចេញពីប្រព័ន្ធដោយជោគជ័យ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: primaryBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Navigate to login
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  void _confirmLogout() {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.logout, color: Colors.orange.shade700),
            ),
            const SizedBox(width: 12),
            Text(t.logout),
          ],
        ),
        content: Text(t.confirmExit),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              t.no,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(t.okay),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: Text(
          ' ' + t.safetyChecklists,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
            color: darkBlue,
          ),
        ),
        centerTitle: false,
        backgroundColor: darkBlue,
        foregroundColor: darkBlue,
        elevation: 0,
        toolbarHeight: 70,
        titleSpacing: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200.withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        leadingWidth: 70,
        leading: Builder(
          builder: (context) => Padding(
            padding:
                const EdgeInsets.only(left: 15, right: 10, top: 15, bottom: 15),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceBlue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.menu_rounded, size: 22),
                onPressed: () => Scaffold.of(context).openDrawer(),
                tooltip: 'Menu',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ),
        actions: [
          // View Toggle (List/Grid)

          // Filter with badge
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _selectedFilter != 'all'
                      ? [primaryBlue, secondaryBlue]
                      : [
                          surfaceBlue.withOpacity(0.9),
                          lightBlue.withOpacity(0.9)
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _selectedFilter != 'all'
                        ? primaryBlue.withOpacity(0.3)
                        : primaryBlue.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showFilterDialog,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.filter_list_rounded,
                          size: 22,
                          color: _selectedFilter != 'all'
                              ? Colors.white
                              : darkBlue,
                        ),
                      ),
                    ),
                  ),
                  if (_selectedFilter != 'all')
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryBlue.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Refresh with animation
          Padding(
            padding:
                const EdgeInsets.only(left: 8, right: 16, top: 8, bottom: 8),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 300),
              tween: Tween(begin: 0, end: _isLoading ? 1 : 0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      surfaceBlue.withOpacity(0.9),
                      lightBlue.withOpacity(0.9)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _refreshChecklists,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 22,
                        color: darkBlue,
                      ),
                    ),
                  ),
                ),
              ),
              builder: (context, value, child) {
                return Transform.rotate(
                  angle: value * 6.28,
                  child: child,
                );
              },
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

                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showSearchDialog,
                              borderRadius: BorderRadius.circular(14),
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(Icons.search_rounded, size: 22),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceBlue.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildViewToggleButton(
                                  Icons.view_list_rounded, false),
                              _buildViewToggleButton(
                                  Icons.grid_view_rounded, true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Checklists List/Grid
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
                        : _isGridView
                            ? _buildGridView()
                            : _buildListView(),
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
        child: FloatingActionButton(
          onPressed: () => _navigateToForm(),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          backgroundColor: primaryBlue,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggleButton(IconData icon, bool isGrid) {
    final isSelected = _isGridView == isGrid;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isGridView = isGrid;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : darkBlue,
        ),
      ),
    );
  }

  SliverPadding _buildListView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == _filteredChecklists.length) {
              return _buildLoadingMoreIndicator();
            }
            return _buildModernChecklistCard(_filteredChecklists[index]);
          },
          childCount: _filteredChecklists.length + (_hasMore ? 1 : 0),
        ),
      ),
    );
  }

  SliverPadding _buildGridView() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == _filteredChecklists.length) {
              return _buildGridLoadingMoreIndicator();
            }
            return _buildGridChecklistCard(_filteredChecklists[index]);
          },
          childCount: _filteredChecklists.length + (_hasMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildGridChecklistCard(ServiceChecker checklist) {
    final passRate = checklist.passRate;
    final statusColor = _getPassRateColor(passRate);
    final statusBgColor = _getPassRateBackgroundColor(passRate);
    final statusIcon = _getPassRateIcon(passRate);
    final statusLabel = _getPassRateLabel(passRate);

    final bool isCreator = _userData != null &&
        checklist.createdBy != null &&
        _userData!['username'] == checklist.createdBy!.username;

    final bool canCancel = !checklist.isCancelled && isCreator;

    final bool hasFailedRequiredItems = checklist.items.any((serviceItem) =>
        serviceItem.notes.any((note) => note.isRequired && !note.passed));
    final int failedRequiredCount = checklist.items.fold(
        0,
        (sum, serviceItem) =>
            sum +
            serviceItem.notes
                .where((note) => note.isRequired && !note.passed)
                .length);

    return GestureDetector(
      onTap: () => _navigateToDetail(checklist),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: hasFailedRequiredItems
                  ? Colors.red.shade100.withOpacity(0.5)
                  : Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Bar - shows pass rate and status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$statusLabel • ${passRate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!canCancel && checklist.createdBy != null)
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
            ),

            // Main Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // License Plate Row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          checklist.licensePlate,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Date Row
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          checklist.createdAtFormattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Created By Row
                  if (checklist.createdBy != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isCreator
                              ? Icons.person_rounded
                              : Icons.person_outline_rounded,
                          size: 12,
                          color: isCreator ? primaryBlue : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isCreator
                                ? 'បង្កើតឡើងដោយ: អ្នក'
                                : 'បង្កើតឡើងដោយ: ${checklist.createdBy!.displayName}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isCreator
                                  ? primaryBlue
                                  : Colors.grey.shade600,
                              fontWeight: isCreator
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                              fontStyle: isCreator
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Item Summary Chips
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryChip(
                          Icons.check_rounded,
                          '${checklist.checkedCount} មាន',
                          Colors.green,
                          isGrid: true,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildSummaryChip(
                          Icons.close_rounded,
                          '${checklist.notCheckedCount} មិនមាន',
                          Colors.red,
                          isGrid: true,
                        ),
                      ),
                    ],
                  ),

                  // Failed Required Items Warning (if any)
                  if (hasFailedRequiredItems) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.shade200,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⛔ មិនអាចចូលឬកឡើងទំនិញ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            failedRequiredCount == 1
                                ? '១ លក្ខខណ្ឌត្រូវតែមាន'
                                : '$failedRequiredCount លក្ខខណ្ឌត្រូវតែមាន',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, String label, Color color,
      {bool isGrid = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isGrid ? 6 : 10,
        vertical: isGrid ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isGrid ? 12 : 20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isGrid ? 12 : 14,
            color: color,
          ),
          SizedBox(width: isGrid ? 2 : 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isGrid ? 9 : 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridStat(IconData icon, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    print("_userData $_userData");
    final String userName = _userData?['username'] ?? 'User';
    final String userRole = _userData?['role'] ?? 'Inspector';
    final String userInitial =
        userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final t = AppLocalizations.of(context)!;
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      width: MediaQuery.of(context).size.width * 0.75,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              surfaceBlue,
            ],
          ),
        ),
        child: Column(
          children: [
            // Drawer Header with User Info
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [darkBlue, primaryBlue],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // User Avatar
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            userInitial,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                userRole,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Drawer Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard_rounded,
                    label: t.dashboardOverview,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.language_rounded,
                    label: AppLocalizations.of(context)!.language,
                    onTap: () {
                      Navigator.pop(context);
                      _showLanguageDialog(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.info_outline_rounded,
                    label: t.about,
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog();
                    },
                  ),
                ],
              ),
            ),

            // Logout Button
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.logout_rounded, color: Colors.red.shade700),
                ),
                title: Text(
                  t.logout,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmLogout();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Version Info
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: surfaceBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryBlue, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: darkBlue,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.grey.shade400,
        size: 14,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            AppLocalizations.of(context)!.language,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(
                context,
                title: AppLocalizations.of(context)!.english,
                locale: const Locale('en', 'US'),
              ),
              const SizedBox(height: 12),
              _buildLanguageOption(
                context,
                title: AppLocalizations.of(context)!.khmer,
                locale: const Locale('km', 'KH'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String title,
    required Locale locale,
  }) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isSelected = settingsProvider.instanceCurrentLocale.languageCode ==
        locale.languageCode;

    // Define colors (you might already have these in your theme)
    final Color primaryBlue = Theme.of(context).primaryColor;
    final Color surfaceBlue = primaryBlue.withOpacity(0.1);
    final Color darkBlue = const Color(0xFF1E3A5F); // or from theme

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        context.read<SettingsProvider>().changeLocale(locale);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? surfaceBlue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? darkBlue : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? darkBlue : darkBlue,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: darkBlue,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStat(String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: darkBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: darkBlue,
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: surfaceBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: primaryBlue),
            ),
            const SizedBox(width: 12),
            Text(t.about),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.safety_check,
                size: 40,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.appName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.version("1.0.1"),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.appDescription,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.close),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDashboard(Map<String, dynamic> stats) {
    final t = AppLocalizations.of(context)!;
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
                    t.dashboardOverview,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.safetyChecklists,
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
                  t.totalChecks,
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
                  t.thisWeek,
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
                  '${stats['avgPassRate'].toStringAsFixed(0)}%',
                  t.avgPassRate,
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
    final statusColor = _getPassRateColor(passRate);
    final statusBgColor = _getPassRateBackgroundColor(passRate);
    final statusIcon = _getPassRateIcon(passRate);
    final statusLabel = _getPassRateLabel(passRate);

    final bool isCreator = _userData != null &&
        checklist.createdBy != null &&
        _userData!['username'] == checklist.createdBy!.username;

    final bool canCancel = !checklist.isCancelled && isCreator;

    final bool hasFailedRequiredItems = checklist.items.any((serviceItem) =>
        serviceItem.notes.any((note) => note.isRequired && !note.passed));
    final int failedRequiredCount = checklist.items.fold(
        0,
        (sum, serviceItem) =>
            sum +
            serviceItem.notes
                .where((note) => note.isRequired && !note.passed)
                .length);

    return Dismissible(
      key: Key('checklist_${checklist.id}'),
      direction:
          canCancel ? DismissDirection.endToStart : DismissDirection.none,
      background: canCancel
          ? Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(Icons.cancel_rounded,
                  color: Colors.white, size: 28),
            )
          : null,
      confirmDismiss: (direction) async {
        if (!canCancel) {
          _showCannotCancelDialog();
          return false;
        }
        return await _showCancelDialog(checklist);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: hasFailedRequiredItems
                  ? Colors.red.shade100.withOpacity(0.5)
                  : Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () => _navigateToDetail(checklist),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            statusIcon,
                            color: statusColor,
                            size: 22,
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
                                child: Row(
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
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${passRate.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: statusColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '• $statusLabel',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: statusColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.grey.shade400,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Date Row
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text(
                                checklist.createdAtFormattedTime,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (!canCancel &&
                                  checklist.createdBy != null) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ],
                            ],
                          ),

                          // Created By Row
                          if (checklist.createdBy != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  isCreator
                                      ? Icons.person_rounded
                                      : Icons.person_outline_rounded,
                                  size: 14,
                                  color: isCreator
                                      ? primaryBlue
                                      : Colors.grey.shade500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isCreator
                                      ? 'បង្កើតឡើងដោយ: អ្នក'
                                      : 'បង្កើតឡើងដោយ: ${checklist.createdBy!.displayName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCreator
                                        ? primaryBlue
                                        : Colors.grey.shade600,
                                    fontWeight: isCreator
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                    fontStyle: isCreator
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Item Summary Chips
                          Row(
                            children: [
                              _buildSummaryChip(
                                Icons.check_rounded,
                                '${checklist.checkedCount} ត្រឹមត្រូវ',
                                Colors.green,
                              ),
                              const SizedBox(width: 8),
                              _buildSummaryChip(
                                Icons.close_rounded,
                                '${checklist.notCheckedCount} មិនត្រឹមត្រូវ',
                                Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Warning Row at Bottom (only if has failed required items)
              if (hasFailedRequiredItems)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ឡាននេះមិនអាចចូលឬកឡើងទំនិញបាននោះទេ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade800,
                              ),
                            ),
                            Text(
                              failedRequiredCount == 1
                                  ? 'មាន ១ លក្ខខណ្ឌត្រូវតែមាន សូមត្រួតពិនិត្យម្ដងទៀត'
                                  : 'មាន $failedRequiredCount លក្ខខណ្ឌត្រូវតែមាន សូមត្រួតពិនិត្យម្ដងទៀត',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Edit Button (positioned at bottom right)
                      if (isCreator)
                        Positioned(
                          bottom: 8,
                          right: 16,
                          child: GestureDetector(
                            onTap: () {
                              // Navigate to edit form
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChecklistFormScreen(
                                    checklistToEdit: checklist,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryBlue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryBlue.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCannotCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.info_outline_rounded, color: primaryBlue),
            ),
            const SizedBox(width: 12),
            const Text('Cannot Cancel'),
          ],
        ),
        content: const Text(
          'You can only cancel checklists that you created.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showCancelDialog(ServiceChecker checklist) async {
    TextEditingController reasonController = TextEditingController();
    bool isReasonValid = true;

    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24), // Add padding to ensure space around dialog
          child: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with gradient - Fixed header (non-scrollable)
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.orange.shade700,
                            Colors.orange.shade400,
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'បោះបង់ការត្រួតពិនិត្យមួយនេះ?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable content
                    Flexible(
                      // Use Flexible instead of Expanded to allow content to shrink
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Warning message
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'សកម្មភាពនេះមិនអាចត្រឡប់ក្រោយបានទេ។ សូមបញ្ជាក់មូលហេតុនៃការលុបចោល។',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // License plate info
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primaryBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.local_taxi,
                                      color: primaryBlue,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ផ្លាកលេខរថយន្ត',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        checklist.licensePlate,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: darkBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Reason field with cool design
                            Text(
                              'មូលហេតុនៃការលុបចោល',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isReasonValid
                                      ? Colors.grey.shade300
                                      : Colors.red.shade400,
                                  width: isReasonValid ? 1 : 2,
                                ),
                              ),
                              child: TextField(
                                controller: reasonController,
                                maxLines: 4,
                                minLines:
                                    3, // Add minLines to ensure consistent size
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'សូមផ្តល់មូលហេតុនៃការលុបចោល...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(16),
                                  suffixIcon: isReasonValid
                                      ? null
                                      : Icon(
                                          Icons.error_outline,
                                          color: Colors.red.shade400,
                                          size: 20,
                                        ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    isReasonValid = true;
                                  });
                                },
                              ),
                            ),

                            if (!isReasonValid) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Reason is required',
                                style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Back',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (reasonController.text
                                          .trim()
                                          .isEmpty) {
                                        setState(() {
                                          isReasonValid = false;
                                        });
                                        return;
                                      }
                                      _cancelChecklist(checklist.id!,
                                          reasonController.text.trim());
                                      Navigator.pop(context, true);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Confirm',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _cancelChecklist(int id, String reason) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.cancelChecklist(id, reason);

      // Refresh the list after cancellation
      await _loadChecklists();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Checklist cancelled successfully')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('Error cancelling checklist: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  Widget _buildGridLoadingMoreIndicator() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 28,
                color: primaryBlue.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'No Checklists Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter != 'all'
                  ? 'No checklists found for selected filter'
                  : 'Start by creating your first safety checklist',
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
    final t = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled:
          true, // Allow the bottom sheet to be scroll controlled
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
            Text(
              t.filterChecklists,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.selectTimePeriod,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            // Wrap the filter options in Flexible to handle overflow
            SingleChildScrollView(
              child: ListView(
                shrinkWrap: true, // Make ListView take only needed space
                padding: EdgeInsets.zero,
                children: [
                  _buildFilterOption(
                      t.allTime, 'all', Icons.calendar_view_month_rounded),
                  _buildFilterOption(t.today, 'today', Icons.today_rounded),
                  _buildFilterOption(
                      t.yesterday, 'yesterday', Icons.history_rounded),
                  _buildFilterOption(
                      t.last7Days, 'last7Days', Icons.date_range_rounded),
                  _buildFilterOption(
                      t.last30Days, 'last30Days', Icons.calendar_month_rounded),
                ],
              ),
            ),
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
        builder: (context) =>
            ChecklistDetailScreen(checklistId: checklist.id as int),
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

  Color _getPassRateColor(double passRate) {
    if (passRate >= 90) {
      return Colors.green;
    } else if (passRate >= 75) {
      return Colors.lightGreen;
    } else if (passRate >= 50) {
      return Colors.orange;
    } else if (passRate >= 25) {
      return Colors.deepOrange;
    } else {
      return Colors.red;
    }
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
        final passRate = checklist.passRate;
        final statusColor = _getPassRateColor(passRate);
        final statusBgColor = statusColor.withOpacity(0.1);

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
                color: statusBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.directions_car_rounded,
                color: statusColor,
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
                color: statusBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${passRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: statusColor,
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
