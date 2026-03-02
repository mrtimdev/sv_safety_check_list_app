import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:safety_check_list/models/device_info.dart';
import 'package:safety_check_list/models/service_checker.dart';
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

  DeviceInfo? _deviceInfo;
  bool _loadingDeviceInfo = true;

  // User data
  Map<String, dynamic>? _userData;

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
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _apiService.getChecklists(
        page: _currentPage,
        limit: 20,
        dateFilter: _selectedFilter != 'all' ? _selectedFilter : null,
        deviceInfo: _deviceInfo!,
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
      // Count checklists for this week
      if (checklist.date.isAfter(weekAgo)) {
        thisWeek++;
      }

      // Sum individual checklist pass rates for average
      totalPassRate += checklist.passRate;

      // Sum total items and checked items for overall pass rate
      totalItems += checklist.totalItems;
      totalChecked += checklist.checkedCount;
    }

    // Average pass rate across all checklists
    double avgPassRate = total > 0 ? totalPassRate / total : 0;

    // Overall pass rate = all checked items / all items * 100
    double overallPassRate = totalPassRate > 0 ? totalPassRate : 0;

    return {
      'total': total,
      'thisWeek': thisWeek,
      'avgPassRate': avgPassRate,
      'overallPassRate': overallPassRate,
      'totalItems': totalItems,
      'totalChecked': totalChecked,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            const Text('ចាកចេញពីប្រព័ន្ធ'),
          ],
        ),
        content: const Text('តើអ្នកពិតជាចង់ចាកចេញពីប្រព័ន្ធមែនទេ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'ទេ',
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
            child: const Text('ចាកចេញ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text(
          ' Safety Checklists',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        centerTitle: false, // Changed to false to move title left
        backgroundColor: darkBlue,
        foregroundColor: darkBlue,
        elevation: 0,
        toolbarHeight: 70,
        titleSpacing: 0, // Remove default spacing
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
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
        leadingWidth: 70, // Set fixed width for leading area
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
                padding: EdgeInsets.zero, // Remove default padding
                constraints:
                    const BoxConstraints(), // Remove default constraints
              ),
            ),
          ),
        ),
        actions: [
          // Search
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
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
                  onTap: _showSearchDialog,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.search_rounded, size: 22),
                  ),
                ),
              ),
            ),
          ),

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
                  // Badge indicator when filter is active
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

  Widget _buildDrawer() {
    print("_userData $_userData");
    final String userName = _userData?['username'] ?? 'User';
    final String userRole = _userData?['role'] ?? 'Inspector';
    final String userInitial =
        userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

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
                    label: 'Dashboard',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.assignment_rounded,
                    label: 'My Checklists',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Statistics',
                    onTap: () {
                      Navigator.pop(context);
                      _showStatisticsDialog();
                    },
                  ),
                  // _buildDrawerItem(
                  //   icon: Icons.settings_rounded,
                  //   label: 'Settings',
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     // Navigate to settings
                  //   },
                  // ),
                  // _buildDrawerItem(
                  //   icon: Icons.help_outline_rounded,
                  //   label: 'Help & Support',
                  //   onTap: () {
                  //     Navigator.pop(context);
                  //     // Show help
                  //   },
                  // ),
                  _buildDrawerItem(
                    icon: Icons.info_outline_rounded,
                    label: 'About',
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
                  'ចាកចេញពីប្រព័ន្ធ',
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

  void _showStatisticsDialog() {
    final stats = _calculateStats();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: surfaceBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bar_chart_rounded, color: primaryBlue),
            ),
            const SizedBox(width: 12),
            const Text('Statistics Overview'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Total Checklists', stats['total'].toString()),
            _buildStatRow('This Week', stats['thisWeek'].toString()),
            _buildStatRow('Average Pass Rate',
                '${stats['overallPassRate'].toStringAsFixed(1)}%'),
            _buildStatRow('Total Items', stats['totalItems'].toString()),
            _buildStatRow(
                'Total Checked Items', stats['totalChecked'].toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            const Text('About'),
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
            const Text(
              'Safety Check',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'A comprehensive vehicle inspection system for safety compliance and monitoring.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
                    'Safety checklists',
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
    final statusColor = passRate >= 80
        ? primaryBlue.withOpacity(0.7)
        : primaryBlue.withOpacity(0.3);
    final isExcellent = passRate >= 90;

    // Check if current user is the creator of this checklist
    final bool isCreator = _userData != null &&
        checklist.createdBy != null &&
        _userData!['username'] == checklist.createdBy!.username;

    // Check if checklist can be cancelled (not already cancelled and user is creator)
    final bool canCancel = !checklist.isCancelled && isCreator;

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
                                // Show owner badge if not creator
                              ],
                            ),
                          ),
                          // if (!isCreator && checklist.createdBy != null) ...[
                          //   const SizedBox(width: 6),
                          //   Container(
                          //     padding: const EdgeInsets.symmetric(
                          //         horizontal: 6, vertical: 2),
                          //     decoration: BoxDecoration(
                          //       color: darkBlue.withOpacity(0.1),
                          //       borderRadius: BorderRadius.circular(4),
                          //     ),
                          //     child: Text(
                          //       'owner',
                          //       style: TextStyle(
                          //         fontSize: 9,
                          //         color: Colors.grey.shade600,
                          //         fontWeight: FontWeight.w500,
                          //       ),
                          //     ),
                          //   ),
                          // ],
                          // const SizedBox(width: 8),
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
                          // Show lock icon if cannot cancel
                          if (!canCancel && checklist.createdBy != null) ...[
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
                                  ? 'Created by you'
                                  : 'Created by: ${checklist.createdBy!.displayName}',
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
                            '${checklist.checkedCount} មាន',
                            Colors.grey.shade700,
                          ),
                          const SizedBox(width: 8),
                          _buildSummaryChip(
                            Icons.close_rounded,
                            '${checklist.notCheckedCount} មិនមាន',
                            Colors.grey.shade700,
                          ),
                          if (checklist.itemNoteCount > 0) ...[
                            const SizedBox(width: 8),
                            _buildSummaryChip(
                              Icons.note_alt_rounded,
                              '${checklist.itemNoteCount} ចំនួនសំណួរ',
                              Colors.grey.shade700,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Add this helper method
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
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(20),
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
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'បោះបង់ការត្រួតពិនិត្យមួយនេះ?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    if (reasonController.text.trim().isEmpty) {
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
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.cancel_outlined,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Confirm Cancel',
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
            // const SizedBox(height: 8),
            // Text(
            //   _errorMessage!,
            //   textAlign: TextAlign.center,
            //   style: TextStyle(
            //     color: Colors.grey.shade600,
            //     fontSize: 14,
            //     height: 1.5,
            //   ),
            // ),
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
