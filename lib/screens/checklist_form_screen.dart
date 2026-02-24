import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:safety_check_list/models/device_info.dart';
import '../models/category.dart';
import '../models/inspection.dart';
import '../models/service_checker.dart';
import '../widgets/category_card.dart';
import '../services/api_service.dart';
import '../widgets/loading_indicator.dart';
import 'license_plate_scanner_screen.dart';

class ChecklistFormScreen extends StatefulWidget {
  final ServiceChecker? checklistToEdit;

  const ChecklistFormScreen({
    Key? key,
    this.checklistToEdit,
  }) : super(key: key);

  @override
  State<ChecklistFormScreen> createState() => _ChecklistFormScreenState();
}

class _ChecklistFormScreenState extends State<ChecklistFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  String _licensePlate = '';
  String? _imagePath;
  DateTime _selectedDate = DateTime.now();

  // Data from API
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  DeviceInfo? _deviceInfo;
  bool _loadingDeviceInfo = true;

  // Inspections map
  late Map<int, List<Inspection>> _inspections;

  // Track which items need note validation
  final Map<int, bool> _noteValidationErrors = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadDeviceInfo();

    // If editing existing checklist
    if (widget.checklistToEdit != null) {
      _licensePlate = widget.checklistToEdit!.licensePlate;
      _imagePath = widget.checklistToEdit!.imagePath;
      _selectedDate = widget.checklistToEdit!.date;
      _inspections = widget.checklistToEdit!.items
          .map((item) {
            return Inspection(
              itemId: item.id,
              itemName: item.khmerName ?? item.name,
              passed: item.passed,
              note: item.note,
            );
          })
          .toList()
          .asMap()
          .map(
              (index, inspection) => MapEntry(inspection.itemId, [inspection]));
    }
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

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final categories = await _apiService.getCategories();
      setState(() {
        _categories = categories;
        _initializeInspections();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load categories: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _initializeInspections() {
    // Only initialize if not editing or if inspections are empty
    if (widget.checklistToEdit == null || _inspections.isEmpty) {
      _inspections = {};
      for (var category in _categories) {
        _inspections[category.id] = category.items
            .map((item) => Inspection(
                  itemId: item.id,
                  itemName: item.khmerName,
                  passed: true,
                  note: null,
                ))
            .toList();
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A), // Deep blue
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _scanLicensePlate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LicensePlateScannerScreen(
          onPlateScanned: (plate, imagePath) {
            setState(() {
              _licensePlate = plate;
              _imagePath = imagePath;
            });
          },
        ),
      ),
    );
  }

  bool _validateForm() {
    bool isValid = _formKey.currentState!.validate();

    // Check for failed items without notes
    _noteValidationErrors.clear();

    _inspections.forEach((categoryId, inspections) {
      for (var inspection in inspections) {
        if (!inspection.passed &&
            (inspection.note == null || inspection.note!.trim().isEmpty)) {
          _noteValidationErrors[inspection.itemId] = true;
          isValid = false;
        }
      }
    });

    setState(() {});

    if (!isValid && _noteValidationErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Please add notes for all failed items'),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    return isValid;
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare categories data matching Spring Boot CategoryItemRequest structure
      final List<Map<String, dynamic>> categoriesData = [];

      for (var category in _categories) {
        final categoryInspections = _inspections[category.id] ?? [];

        // Prepare items for this category
        final List<Map<String, dynamic>> itemsData = [];

        for (var inspection in categoryInspections) {
          itemsData.add({
            'itemId': inspection.itemId,
            'passed': inspection.passed,
            'note': inspection.passed
                ? null
                : inspection.note, // Only send note if failed
          });
        }

        // Add category with its items
        categoriesData.add({
          'categoryId': category.id,
          'items': itemsData,
        });
      }

      // Prepare the complete request data matching Spring Boot ServiceCheckerRequest
      final Map<String, dynamic> requestData = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'licensePlate': _licensePlate.toUpperCase().trim(),
        'driverId': 1, // Default driver ID
        'categories': categoriesData,
      };

      print('📤 Submitting form data: ${json.encode(requestData)}');

      // Create image file if path exists
      File? imageFile;
      if (_imagePath != null && _imagePath!.isNotEmpty) {
        imageFile = File(_imagePath!);
        if (await imageFile.exists()) {
          print('📸 Image file exists: ${imageFile.path}');
        } else {
          print('⚠️ Image file does not exist: $_imagePath');
          imageFile = null;
        }
      }

      if (widget.checklistToEdit != null) {
        // Update existing checklist with optional image
        final response = await _apiService.updateChecklist(
          widget.checklistToEdit!.id!,
          requestData,
          imageFile: imageFile,
          deviceInfo: _deviceInfo!,
        );

        print('✅ Update response: $response');

        if (mounted) {
          _showSuccessSnackbar(
              response['message'] ?? 'Checklist updated successfully!');
        }
      } else {
        // Create new checklist with image
        final response = await _apiService.createChecklist(
          requestData,
          imageFile: imageFile,
          deviceInfo: _deviceInfo!,
        );

        print('✅ Create response: $response');

        if (mounted) {
          _showSuccessSnackbar(
              response['message'] ?? 'Checklist created successfully!');
        }
      }

      if (mounted) {
        // Navigate back with success
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      print('❌ Error submitting form: $e');

      if (mounted) {
        _showErrorSnackbar(e.toString());
      }
    }
  }

  void _showSuccessSnackbar(String message) {
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
              child:
                  const Icon(Icons.check, color: Color(0xFF1E3A8A), size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String error) {
    String errorMessage = error.replaceAll('Exception: ', '');

    Color bgColor = errorMessage.contains('already exists')
        ? Colors.orange.shade700
        : Colors.red.shade700;

    IconData icon = errorMessage.contains('already exists')
        ? Icons.warning_amber
        : Icons.error;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(errorMessage),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 5),
        action: errorMessage.contains('already exists')
            ? SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              )
            : null,
      ),
    );
  }

  void _updateInspection(
      int categoryId, int itemId, bool passed, String? note) {
    setState(() {
      final inspections = _inspections[categoryId];
      if (inspections != null) {
        final index = inspections.indexWhere((i) => i.itemId == itemId);
        if (index != -1) {
          inspections[index].passed = passed;
          inspections[index].note = note;

          // Clear validation error if note is provided
          if (!passed && note != null && note.isNotEmpty) {
            _noteValidationErrors.remove(itemId);
          } else if (!passed && (note == null || note.isEmpty)) {
            _noteValidationErrors[itemId] = true;
          } else if (passed) {
            _noteValidationErrors.remove(itemId);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDeviceInfo) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.checklistToEdit != null
              ? 'Edit Safety Check'
              : 'New Safety Check'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF1E3A8A)),
              SizedBox(height: 16),
              Text('Loading device information...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.checklistToEdit != null
              ? 'Edit Safety Check'
              : 'New Safety Check',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A8A),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && _categories.isEmpty
          ? const LoadingIndicator(message: 'Loading categories...')
          : _errorMessage != null
              ? _buildErrorWidget()
              : Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Header with progress
                      _buildHeader(),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            children: [
                              // License Plate Section
                              _buildLicensePlateSection(),

                              // Date Picker
                              _buildDateSection(),

                              const SizedBox(height: 8),

                              // Categories List
                              _categories.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(32),
                                        child: Text('No categories available'),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _categories.length,
                                      itemBuilder: (context, index) {
                                        final category = _categories[index];
                                        final inspections =
                                            _inspections[category.id] ?? [];
                                        return CategoryCard(
                                          category: category,
                                          inspections: inspections,
                                          validationErrors:
                                              _noteValidationErrors,
                                          onInspectionChanged:
                                              (itemId, passed, note) {
                                            _updateInspection(
                                              category.id,
                                              itemId,
                                              passed,
                                              note,
                                            );
                                          },
                                        );
                                      },
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    int totalItems =
        _inspections.values.fold(0, (sum, list) => sum + list.length);
    int failedItems = _inspections.values
        .fold(0, (sum, list) => sum + list.where((i) => !i.passed).length);
    int itemsWithNotes = _inspections.values.fold(
        0,
        (sum, list) =>
            sum +
            list
                .where((i) => !i.passed && i.note != null && i.note!.isNotEmpty)
                .length);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment,
                color: Color(0xFF1E3A8A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inspection Progress',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$failedItems of $totalItems items failed',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          if (failedItems > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: itemsWithNotes == failedItems
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    itemsWithNotes == failedItems
                        ? Icons.check_circle
                        : Icons.warning,
                    size: 14,
                    color: itemsWithNotes == failedItems
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$itemsWithNotes/$failedItems notes',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: itemsWithNotes == failedItems
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLicensePlateSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_taxi,
                    color: Color(0xFF1E3A8A), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'License Plate',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF1E3A8A).withOpacity(0.2)),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _licensePlate,
                  decoration: InputDecoration(
                    hintText: 'KH-1234',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.directions_car,
                        color: Color(0xFF1E3A8A)),
                    suffixIcon: _imagePath != null
                        ? Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) => _licensePlate = value.toUpperCase(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter license plate';
                    }
                    if (value.length < 3) {
                      return 'License plate is too short';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: _scanLicensePlate,
                  tooltip: 'Scan License Plate',
                ),
              ),
            ],
          ),
          if (_imagePath != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'License plate image captured',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () => setState(() => _imagePath = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_today,
                color: Color(0xFF1E3A8A), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inspection Date',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border:
                  Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: _selectDate,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A8A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Change'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCategories,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
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

  Widget _buildBottomBar() {
    if (_isLoading && _categories.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.checklistToEdit != null ? 'Update' : 'Save',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
