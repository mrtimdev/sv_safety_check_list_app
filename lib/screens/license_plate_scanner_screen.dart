import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:safety_check_list/l10n/app_localizations.dart';
import 'package:safety_check_list/services/api_service.dart';
import 'package:safety_check_list/widgets/gradient_app_bar.dart';
import '../widgets/loading_indicator.dart';

class LicensePlateScannerScreen extends StatefulWidget {
  final Function(
          String licensePlate, String? licensePlateEstimated, String imagePath)
      onPlateScanned;

  const LicensePlateScannerScreen({
    Key? key,
    required this.onPlateScanned,
    required String? licensePlateEstimated,
    required String imagePath,
  }) : super(key: key);

  @override
  State<LicensePlateScannerScreen> createState() =>
      _LicensePlateScannerScreenState();
}

class _LicensePlateScannerScreenState extends State<LicensePlateScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _extractedText;
  String? _extractedTextEstimated;
  bool _isProcessing = false;

  final ApiService _apiService = ApiService();

  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color primaryBlue = Color(0xFF1E40AF);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color accentBlue = Color(0xFF60A5FA);
  static const Color lightBlue = Color(0xFFDBEAFE);
  static const Color darkBlue = Color(0xFF1E3A8A);
  static const Color surfaceBlue = Color(0xFFF0F9FF);

  Future<String?> _saveImagePermanently(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        print('❌ Source image file does not exist: ${imageFile.path}');
        return null;
      }

      final Directory appDir = await getApplicationDocumentsDirectory();

      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }

      final String fileName =
          'license_plate_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String localPath = '${appDir.path}/$fileName';

      final Uint8List imageBytes = await imageFile.readAsBytes();
      final File localImage = File(localPath);
      await localImage.writeAsBytes(imageBytes);

      print('✅ Image saved permanently at: $localPath');
      return localPath;
    } catch (e) {
      print('❌ Error saving image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: GradientAppBar(
        title: t.scanPlateNumber,
        showLoading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image,
                                      size: 40, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text('បរាជ័យក្នុងការស្គេនរូបភាព',
                                      style:
                                          TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 60,
                              color: primaryColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ថតរូបផ្លាកលេខរថយន្ត ឬជ្រើសរើសពីថតរូប',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _takePhoto,
                      icon: const Icon(Icons.camera),
                      label: const Text('កាមេរ៉ា'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _pickFromGallery,
                      icon: Icon(Icons.photo_library, color: primaryColor),
                      label: Text('ជ្រើសរើសពីថតរូប',
                          style: TextStyle(color: primaryColor)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isProcessing) ...[
                const SizedBox(height: 24),
                const LoadingIndicator(message: 'កំពុងស្កេនផ្លាកលេខ...'),
              ],
              if (_extractedText != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryColor),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: primaryColor, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'ផ្លាកលេខដែលបានរកឃើញ:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _extractedText!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      if (_extractedTextEstimated != null &&
                          _extractedTextEstimated!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text(
                          'អក្សរដែលបានស្កេនពីរូបភាព:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _extractedTextEstimated!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _extractedText = null;
                            _extractedTextEstimated = null;
                            _selectedImage = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('ស្កេនម្តងទៀត'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          String? savedPath;
                          if (_selectedImage != null) {
                            savedPath =
                                await _saveImagePermanently(_selectedImage!);
                          }

                          if (savedPath != null && mounted) {
                            widget.onPlateScanned(
                              _extractedText!,
                              _extractedText!,
                              savedPath,
                            );
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'មានបញ្ហាក្នុងការស្គេនរូបភាព។ សូមព្យាយាមម្តងទៀត។'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('ប្រើលេខផ្លាកលេខរថយន្តនេះ'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: primaryColor.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ឬបញ្ចូលដោយដៃ:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'បញ្ចូលលេខផ្លាកលេខរថយន្ត',
                                prefixIcon: Icon(Icons.directions_car,
                                    color: primaryColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: primaryColor.withOpacity(0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: primaryColor.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: primaryColor),
                                ),
                              ),
                              textCapitalization: TextCapitalization.characters,
                              onChanged: (value) {
                                setState(() {
                                  _extractedText = value.toUpperCase();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (_extractedText != null &&
                                  _extractedText!.isNotEmpty) {
                                String? savedPath;
                                if (_selectedImage != null) {
                                  savedPath = await _saveImagePermanently(
                                      _selectedImage!);
                                }

                                widget.onPlateScanned(
                                  _extractedText!,
                                  _extractedText!,
                                  savedPath ?? '',
                                );
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Icon(Icons.check),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _extractedText = null;
        _extractedTextEstimated = null;
      });
      _processImage(image);
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _extractedText = null;
        _extractedTextEstimated = null;
      });
      _processImage(image);
    }
  }

  Future<void> _processImage(XFile imageFile) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // Use the FastAPI endpoint for license plate detection
      final String? plateNumber =
          await _apiService.detectPlate(File(imageFile.path));

      if (!mounted) return;

      if (plateNumber != null) {
        setState(() {
          _isProcessing = false;
          _extractedText = plateNumber;
          _extractedTextEstimated =
              null; // Optional: You could store the raw OCR here if API returns it
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('បានរកឃើញផ្លាកលេខ: $plateNumber'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _isProcessing = false;
          _extractedText = 'រកមិនឃើញផ្លាកលេខរថយន្តទេ';
          _extractedTextEstimated = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'រកមិនឃើញផ្លាកលេខទេ។ សាកល្បងរូបភាពផ្សេងទៀត ឬបញ្ចូលដោយដៃ។'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _extractedText = 'កំហុសក្នុងការស្កេន';
        _extractedTextEstimated = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('កំហុស: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<ui.Image> decodeImageFromList(List<int> bytes) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(Uint8List.fromList(bytes), (ui.Image img) {
      return completer.complete(img);
    });
    return completer.future;
  }
}
