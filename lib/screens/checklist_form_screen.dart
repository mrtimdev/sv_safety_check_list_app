import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:safety_check_list/l10n/app_localizations.dart';
import 'package:safety_check_list/models/device_info.dart';
import 'package:safety_check_list/models/service_checker.dart';
import 'package:safety_check_list/widgets/gradient_app_bar.dart';
import '../models/category.dart';
import '../models/inspection.dart';
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
  String _licensePlateEstimated = '';
  String? _imagePath;
  DateTime _selectedDate = DateTime.now();
  int? _editingId;

  // Data from API
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  DeviceInfo? _deviceInfo;
  bool _loadingDeviceInfo = true;

  // Inspections map organized by category
  late Map<int, List<Inspection>> _inspections;

  // Track which items need note validation
  final Map<int, bool> _noteValidationErrors = {};

  late TextEditingController _licensePlateController;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _loadCategories();

    _licensePlateController = TextEditingController();
    // If editing existing checklist
    if (widget.checklistToEdit != null) {
      _editingId = widget.checklistToEdit!.id;
      _licensePlate = widget.checklistToEdit!.licensePlate;
      _licensePlateEstimated =
          widget.checklistToEdit!.licensePlateEstimated ?? '';
      _imagePath = widget.checklistToEdit!.imagePath;
      _selectedDate = widget.checklistToEdit!.date;

      _licensePlateController.text = _licensePlate;
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
    _inspections = {};

    if (widget.checklistToEdit != null &&
        widget.checklistToEdit!.items.isNotEmpty) {
      // Initialize from existing ServiceChecker data
      print(
          '📋 Initializing from existing checklist with ${widget.checklistToEdit!.items.length} items');

      for (var category in _categories) {
        _inspections[category.id] = [];
      }

      for (var serviceItem in widget.checklistToEdit!.items) {
        final categoryId = serviceItem.category.id;
        final checklistItems = serviceItem.inspectionItems;
        final existingItemIds =
            _inspections[categoryId]?.map((i) => i.itemId).toSet() ?? {};
        for (var item in checklistItems) {
          bool isRequired = false;

          // Find the correct category
          final category = _categories.firstWhere((c) => c.id == categoryId);

          // Find the correct item inside that category
          final categoryItem =
              category.items.firstWhere((ci) => ci.id == item.id);

          isRequired = categoryItem.isRequired;

          print(
              "isRequired for item ${item.id} (${item.khmerName}): $isRequired");

          _inspections[categoryId]?.add(Inspection(
            itemId: item.id,
            itemName: item.khmerName ?? item.name,
            passed: item.passed,
            note: item.note,
            isRequired: isRequired,
          ));
        }
      }
      // for (var category in _categories) {
      //   final existingItemIds =
      //       _inspections[category.id]?.map((i) => i.itemId).toSet() ?? {};

      //   for (var categoryItem in category.items) {
      //     if (!existingItemIds.contains(categoryItem.id)) {
      //       _inspections[category.id]?.add(Inspection(
      //           itemId: categoryItem.id,
      //           itemName: categoryItem.khmerName,
      //           // passed: true,
      //           // note: null,
      //           isRequired: categoryItem.isRequired));
      //     }
      //   }
      // }
    } else {
      // Initialize new checklist with all categories and items defaulting to passed
      for (var category in _categories) {
        _inspections[category.id] = category.items
            .map((item) => Inspection(
                itemId: item.id,
                itemName: item.khmerName,
                passed: true,
                note: null,
                isRequired: item.isRequired))
            .toList();
      }
    }

    // Sort inspections by item ID or name to maintain consistent order
    _inspections.forEach((categoryId, inspections) {
      inspections.sort((a, b) => a.itemId.compareTo(b.itemId));
    });
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
          licensePlateEstimated: _licensePlateEstimated,
          imagePath: _imagePath ?? '',
          onPlateScanned: (plate, estimated, imagePath) {
            print("plate, estimated $plate, $estimated");
            setState(() {
              if (plate.isNotEmpty) {
                _licensePlate =
                    plate.toUpperCase().replaceAll('-', '').replaceAll(' ', '');
              }
              // If no cleaned plate but estimated exists, use estimated
              else if (estimated!.isNotEmpty) {
                _licensePlate = estimated!
                    .toUpperCase()
                    .replaceAll('-', '')
                    .replaceAll(' ', '');
              }

              // Always store the raw estimated text for display
              _licensePlateEstimated =
                  estimated!.isNotEmpty ? estimated!.toUpperCase() : '';

              _licensePlateController.text = _licensePlate;
              _imagePath = imagePath;
            });

            print('📝 License plate set to: $_licensePlate');
            print('📝 Estimated text: $_licensePlateEstimated');
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
      // Prepare categories data matching the backend CategoryItemRequest structure
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

      // return;

      // Prepare the complete request data
      final Map<String, dynamic> requestData = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'licensePlate': _licensePlate.toUpperCase().trim(),
        'licensePlateEstimated': _licensePlateEstimated.isNotEmpty
            ? _licensePlateEstimated.toUpperCase().trim()
            : null,
        'driverId':
            1, // Default driver ID - you might want to make this dynamic
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

      dynamic response;

      if (_editingId != null) {
        // Update existing checklist
        response = await _apiService.updateChecklist(
          _editingId!,
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
        // Create new checklist
        response = await _apiService.createChecklist(
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
        // Navigate back with success and the updated/created data
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

          // Clear validation error if note is provided for failed items
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

  int get _totalItems {
    return _inspections.values.fold(0, (sum, list) => sum + list.length);
  }

  int get _failedItems {
    return _inspections.values
        .fold(0, (sum, list) => sum + list.where((i) => !i.passed).length);
  }

  int get _itemsWithNotes {
    return _inspections.values.fold(
        0,
        (sum, list) =>
            sum +
            list
                .where((i) => !i.passed && i.note != null && i.note!.isNotEmpty)
                .length);
  }

  // Modern blue color palette
  static const Color primaryBlue = Color(0xFF1E40AF);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color accentBlue = Color(0xFF60A5FA);
  static const Color lightBlue = Color(0xFFDBEAFE);
  static const Color darkBlue = Color(0xFF1E3A8A);
  static const Color surfaceBlue = Color(0xFFF0F9FF);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: GradientAppBar(
        title: _editingId != null ? t.editSafetyCheck : t.newSafetyCheck,
        showLoading: _isLoading,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: lightBlue,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _submitForm,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      _editingId != null
                          ? Icons.edit_outlined
                          : Icons.check_circle,
                      size: 20,
                      color: darkBlue,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading && _categories.isEmpty
          ? const LoadingIndicator(message: 'Loading inspection items...')
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
                              // _buildDateSection(),

                              const SizedBox(height: 8),

                              // Categories List
                              _categories.isEmpty
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(32),
                                        child: Text(
                                            'No inspection categories available'),
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
                  '$_failedItems of $_totalItems items failed',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
          if (_failedItems > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _itemsWithNotes == _failedItems
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    _itemsWithNotes == _failedItems
                        ? Icons.check_circle
                        : Icons.warning,
                    size: 14,
                    color: _itemsWithNotes == _failedItems
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_itemsWithNotes/$_failedItems notes',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _itemsWithNotes == _failedItems
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
          // Header Row
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

          // Input Row with TextField and Camera Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expanded TextField
              Expanded(
                child: TextFormField(
                  controller: _licensePlateController,
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
                  // onChanged: (value) => _licensePlate = value.toUpperCase(),
                  onChanged: _updateLicensePlate,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'សូមផ្ទៀងផ្ទាត់ការបញ្ចូលផ្លាកលេខម្តងទៀត';
                    }
                    if (value.length < 3) {
                      return 'ផ្លាកលេខមិនត្រឹមត្រូវ';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Camera Button
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
                  iconSize: 24,
                ),
              ),
            ],
          ),

          if (_imagePath != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'រូបភាពផ្លាកលេខរថយន្ត',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: () => setState(() => _imagePath = null),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (_imagePath != null && _imagePath!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.visibility,
                          size: 16, color: Color(0xFF1E3A8A)),
                      onPressed: () => _showImagePreview(context),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _updateLicensePlate(String value) {
    setState(() {
      _licensePlate = value.toUpperCase();
      _licensePlateEstimated = _licensePlateEstimated.isNotEmpty
          ? _licensePlateEstimated.toUpperCase()
          : _licensePlateEstimated;
    });
  }

  String _removeAllWhitespace(String text) {
    // Remove all whitespace and convert to uppercase
    String cleanText = text.replaceAll(RegExp(r'\s+'), '').toUpperCase();

    // Add space between letters and numbers (e.g., "KH1234" -> "KH 1234")
    final RegExp pattern = RegExp(r'^([A-Z]+)([0-9].*)$');
    return cleanText.replaceFirstMapped(pattern, (match) {
      return '${match[1]} ${match[2]}';
    });
  }

  void _showEstimatedPlateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Scanned License Plate'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Raw scanned text from image:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _licensePlateEstimated,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap "Use This Plate" to copy it to the input field',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _licensePlate = _licensePlateEstimated;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Use This Plate'),
          ),
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                File(_imagePath!),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_rounded,
                              size: 60, color: Colors.white54),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _licensePlate.isNotEmpty
                          ? _licensePlate
                          : 'Vehicle Image',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(_selectedDate),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    final t = AppLocalizations.of(context)!;
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
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(t.cancel),
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
                      _editingId != null ? t.update : t.save,
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
