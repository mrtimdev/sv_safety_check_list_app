// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../models/category.dart';
// import '../models/inspection.dart';
// import '../models/service_checker.dart';
// import '../widgets/category_card.dart';
// import '../services/api_service.dart';
// import '../widgets/loading_indicator.dart';
// import 'license_plate_scanner_screen.dart';

// class ChecklistFormScreen extends StatefulWidget {
//   final ServiceChecker? checklistToEdit;

//   const ChecklistFormScreen({
//     Key? key,
//     this.checklistToEdit,
//   }) : super(key: key);

//   @override
//   State<ChecklistFormScreen> createState() => _ChecklistFormScreenState();
// }

// class _ChecklistFormScreenState extends State<ChecklistFormScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final ApiService _apiService = ApiService();

//   String _licensePlate = '';
//   String? _imagePath;
//   DateTime _selectedDate = DateTime.now();

//   // Data from API
//   List<Category> _categories = [];
//   bool _isLoading = true;
//   String? _errorMessage;

//   // Inspections map
//   late Map<int, List<Inspection>> _inspections;

//   @override
//   void initState() {
//     super.initState();
//     _loadCategories();

//     // If editing existing checklist
//     if (widget.checklistToEdit != null) {
//       _licensePlate = widget.checklistToEdit!.licensePlate;
//       _imagePath = widget.checklistToEdit!.imagePath;
//       _selectedDate = widget.checklistToEdit!.date;
//       _inspections = widget.checklistToEdit!.inspections;
//     }
//   }

//   Future<void> _loadCategories() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     try {
//       final categories = await _apiService.getCategories();
//       setState(() {
//         _categories = categories;
//         _initializeInspections();
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Failed to load categories: ${e.toString()}';
//         _isLoading = false;
//       });
//     }
//   }

//   void _initializeInspections() {
//     // Only initialize if not editing or if inspections are empty
//     if (widget.checklistToEdit == null || _inspections.isEmpty) {
//       _inspections = {};
//       for (var category in _categories) {
//         _inspections[category.id] = category.items
//             .map((item) => Inspection(
//                   itemId: item.id,
//                   itemName: item.khmerName,
//                   passed: true,
//                   note: null,
//                 ))
//             .toList();
//       }
//     }
//   }

//   Future<void> _selectDate() async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: const ColorScheme.light(
//               primary: Colors.blue,
//               onPrimary: Colors.white,
//               surface: Colors.white,
//               onSurface: Colors.black,
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );
//     if (picked != null && picked != _selectedDate) {
//       setState(() {
//         _selectedDate = picked;
//       });
//     }
//   }

//   Future<void> _scanLicensePlate() async {
//     final result = await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => LicensePlateScannerScreen(
//           onPlateScanned: (plate, imagePath) {
//             setState(() {
//               _licensePlate = plate;
//               _imagePath = imagePath;
//             });
//           },
//         ),
//       ),
//     );
//   }

//   Future<void> _submitForm() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() {
//         _isLoading = true;
//       });

//       try {
//         // Prepare the request data matching Spring Boot ServiceCheckerRequest
//         final Map<String, dynamic> requestData = {
//           'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
//           'driverId':
//               1, // You'll need to get this from somewhere - maybe a driver selection screen
//           'categories': _categories.map((category) {
//             final categoryInspections = _inspections[category.id] ?? [];
//             return {
//               'categoryId': category.id,
//               'items': categoryInspections.map((inspection) {
//                 return {
//                   'itemId': inspection.itemId,
//                   'passed': inspection.passed,
//                   'note': inspection.passed
//                       ? null
//                       : inspection.note, // Only send note if failed
//                 };
//               }).toList(),
//             };
//           }).toList(),
//         };

//         print('Submitting form data: $requestData');

//         if (widget.checklistToEdit != null) {
//           // Update existing checklist
//           final response = await _apiService.updateChecklist(
//             widget.checklistToEdit!.id!,
//             requestData,
//           );

//           print('Update response: $response');

//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                     response['message'] ?? 'Checklist updated successfully!'),
//                 backgroundColor: Colors.green,
//               ),
//             );
//           }
//         } else {
//           // Create new checklist
//           final response = await _apiService.createChecklist(requestData);

//           print('Create response: $response');

//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                     response['message'] ?? 'Checklist created successfully!'),
//                 backgroundColor: Colors.green,
//               ),
//             );
//           }
//         }

//         if (mounted) {
//           Navigator.pop(context, true); // Return true to indicate success
//         }
//       } catch (e) {
//         setState(() {
//           _isLoading = false;
//         });

//         print('Error submitting form: $e');

//         if (mounted) {
//           // Check if it's a conflict error (duplicate checklist)
//           if (e.toString().contains('already exists')) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(e.toString().replaceAll('Exception: ', '')),
//                 backgroundColor: Colors.orange,
//                 duration: const Duration(seconds: 5),
//                 action: SnackBarAction(
//                   label: 'OK',
//                   textColor: Colors.white,
//                   onPressed: () {},
//                 ),
//               ),
//             );
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                     'Error: ${e.toString().replaceAll('Exception: ', '')}'),
//                 backgroundColor: Colors.red,
//               ),
//             );
//           }
//         }
//       }
//     }
//   }

//   void _updateInspection(
//       int categoryId, int itemId, bool passed, String? note) {
//     setState(() {
//       final inspections = _inspections[categoryId];
//       if (inspections != null) {
//         final index = inspections.indexWhere((i) => i.itemId == itemId);
//         if (index != -1) {
//           inspections[index].passed = passed;
//           inspections[index].note = note;
//         }
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.checklistToEdit != null
//             ? 'Edit Safety Check'
//             : 'New Safety Check'),
//         backgroundColor: Colors.transparent,
//         foregroundColor: Colors.black,
//         elevation: 0,
//         actions: [
//           if (_isLoading)
//             const Padding(
//               padding: EdgeInsets.all(16.0),
//               child: SizedBox(
//                 width: 20,
//                 height: 20,
//                 child: CircularProgressIndicator(
//                   strokeWidth: 2,
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
//                 ),
//               ),
//             ),
//         ],
//       ),
//       body: _isLoading && _categories.isEmpty
//           ? const LoadingIndicator(message: 'Loading categories...')
//           : _errorMessage != null
//               ? _buildErrorWidget()
//               : Form(
//                   key: _formKey,
//                   child: Column(
//                     children: [
//                       // License Plate Section
//                       _buildLicensePlateSection(),

//                       // Date Picker
//                       _buildDateSection(),

//                       const SizedBox(height: 8),

//                       // Categories List
//                       Expanded(
//                         child: _categories.isEmpty
//                             ? const Center(
//                                 child: Text('No categories available'),
//                               )
//                             : RefreshIndicator(
//                                 onRefresh: _loadCategories,
//                                 child: ListView.builder(
//                                   padding: const EdgeInsets.all(16),
//                                   itemCount: _categories.length,
//                                   itemBuilder: (context, index) {
//                                     final category = _categories[index];
//                                     final inspections =
//                                         _inspections[category.id] ?? [];
//                                     return CategoryCard(
//                                       category: category,
//                                       inspections: inspections,
//                                       onInspectionChanged:
//                                           (itemId, passed, note) {
//                                         _updateInspection(
//                                           category.id,
//                                           itemId,
//                                           passed,
//                                           note,
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               ),
//                       ),
//                     ],
//                   ),
//                 ),
//       bottomNavigationBar: _buildBottomBar(),
//     );
//   }

//   Widget _buildLicensePlateSection() {
//     return Container(
//       margin: const EdgeInsets.all(16),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             spreadRadius: 1,
//             blurRadius: 5,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'License Plate',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(
//                 child: TextFormField(
//                   initialValue: _licensePlate,
//                   decoration: InputDecoration(
//                     hintText: 'Enter plate number',
//                     prefixIcon: const Icon(Icons.directions_car),
//                     suffixIcon: _imagePath != null
//                         ? const Icon(Icons.check_circle, color: Colors.green)
//                         : null,
//                   ),
//                   textCapitalization: TextCapitalization.characters,
//                   onChanged: (value) => _licensePlate = value.toUpperCase(),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter license plate';
//                     }
//                     return null;
//                   },
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Container(
//                 decoration: BoxDecoration(
//                   color: Colors.blue.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: IconButton(
//                   icon: const Icon(Icons.camera_alt, color: Colors.blue),
//                   onPressed: _scanLicensePlate,
//                   tooltip: 'Scan License Plate',
//                 ),
//               ),
//             ],
//           ),
//           if (_imagePath != null) ...[
//             const SizedBox(height: 12),
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.green.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(Icons.check_circle, color: Colors.green, size: 16),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'License plate image captured',
//                       style: const TextStyle(fontSize: 12),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close, size: 16),
//                     onPressed: () => setState(() => _imagePath = null),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildDateSection() {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             spreadRadius: 1,
//             blurRadius: 5,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: Colors.blue.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: const Icon(Icons.calendar_today, color: Colors.blue),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Inspection Date',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.grey,
//                   ),
//                 ),
//                 Text(
//                   DateFormat('dd MMMM yyyy').format(_selectedDate),
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           TextButton(
//             onPressed: _selectDate,
//             style: TextButton.styleFrom(
//               foregroundColor: Colors.blue,
//             ),
//             child: const Text('Change'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildErrorWidget() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.error_outline,
//               size: 64,
//               color: Colors.red[300],
//             ),
//             const SizedBox(height: 16),
//             Text(
//               _errorMessage!,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 color: Colors.grey[600],
//                 fontSize: 14,
//               ),
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton.icon(
//               onPressed: _loadCategories,
//               icon: const Icon(Icons.refresh),
//               label: const Text('Try Again'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 foregroundColor: Colors.white,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildBottomBar() {
//     if (_isLoading && _categories.isNotEmpty) {
//       return Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.1),
//               spreadRadius: 1,
//               blurRadius: 5,
//               offset: const Offset(0, -2),
//             ),
//           ],
//         ),
//         child: const SafeArea(
//           child: Center(
//             child: CircularProgressIndicator(),
//           ),
//         ),
//       );
//     }

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             spreadRadius: 1,
//             blurRadius: 5,
//             offset: const Offset(0, -2),
//           ),
//         ],
//       ),
//       child: SafeArea(
//         child: Row(
//           children: [
//             Expanded(
//               child: OutlinedButton(
//                 onPressed: _isLoading
//                     ? null
//                     : () {
//                         Navigator.pop(context);
//                       },
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: Colors.red,
//                   side: const BorderSide(color: Colors.red),
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 child: const Text('Cancel'),
//               ),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: ElevatedButton(
//                 onPressed: _isLoading ? null : _submitForm,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.green,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 child: Text(widget.checklistToEdit != null
//                     ? 'Update'
//                     : 'Save Checklist'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     super.dispose();
//   }
// }
