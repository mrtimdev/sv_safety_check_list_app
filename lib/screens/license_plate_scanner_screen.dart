import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/loading_indicator.dart';

class LicensePlateScannerScreen extends StatefulWidget {
  final Function(String licensePlate, String? imagePath) onPlateScanned;

  const LicensePlateScannerScreen({
    Key? key,
    required this.onPlateScanned,
  }) : super(key: key);

  @override
  State<LicensePlateScannerScreen> createState() =>
      _LicensePlateScannerScreenState();
}

class _LicensePlateScannerScreenState extends State<LicensePlateScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  String? _extractedText;
  bool _isProcessing = false;

  // Save image to permanent storage
  Future<String?> _saveImagePermanently(File imageFile) async {
    try {
      // Get app documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'license_plate_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String localPath = '${appDir.path}/$fileName';

      // Copy image to permanent storage
      final File localImage = await imageFile.copy(localPath);
      print('✅ Image saved permanently at: $localPath');
      return localPath;
    } catch (e) {
      print('❌ Error saving image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan License Plate'),
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Preview
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Take a photo of license plate',
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

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _takePhoto,
                      icon: const Icon(Icons.camera),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
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
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
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
                const LoadingIndicator(message: 'Scanning license plate...'),
              ],

              if (_extractedText != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        'Detected License Plate:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _extractedText!,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
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
                            _selectedImage = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Scan Again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Save image permanently before returning
                          String? savedPath;
                          if (_selectedImage != null) {
                            savedPath =
                                await _saveImagePermanently(_selectedImage!);
                          }

                          widget.onPlateScanned(
                            _extractedText!,
                            savedPath, // Use permanent path instead of cache
                          );

                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Use This Plate'),
                      ),
                    ),
                  ],
                ),
              ],

              if (_selectedImage != null &&
                  _extractedText == null &&
                  !_isProcessing) ...[
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _scanLicensePlate,
                    icon: const Icon(Icons.scanner),
                    label: const Text('Scan License Plate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              // Manual Input Option
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Or enter manually:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Enter license plate number',
                                prefixIcon: const Icon(Icons.directions_car),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
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
                            onPressed: () {
                              if (_extractedText != null &&
                                  _extractedText!.isNotEmpty) {
                                widget.onPlateScanned(_extractedText!, null);
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
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
      imageQuality: 90, // Higher quality
      maxWidth: 1200, // Reasonable size
      maxHeight: 1200,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _extractedText = null;
      });
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
      });
    }
  }

  Future<void> _scanLicensePlate() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final inputImage = InputImage.fromFile(_selectedImage!);
      final textDetector = TextRecognizer();
      final RecognizedText recognizedText =
          await textDetector.processImage(inputImage);

      // Process the recognized text to find license plate pattern
      String? plateNumber;
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          // Clean the text
          String text =
              line.text.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

          // Common patterns: 2-4 letters followed by 1-4 numbers or vice versa
          if (text.length >= 4 && text.length <= 8) {
            if (RegExp(r'^[A-Z]{2,4}[0-9]{2,4}$').hasMatch(text) ||
                RegExp(r'^[0-9]{2,4}[A-Z]{2,4}$').hasMatch(text)) {
              plateNumber = text;
              break;
            }
          }

          // Also check for patterns with dash (like KH-1234)
          if (line.text.contains('-')) {
            String possiblePlate = line.text.replaceAll(' ', '').toUpperCase();
            if (RegExp(r'^[A-Z]{2,3}-\d{3,4}$').hasMatch(possiblePlate)) {
              plateNumber = possiblePlate;
              break;
            }
          }
        }
        if (plateNumber != null) break;
      }

      await textDetector.close();

      setState(() {
        _isProcessing = false;
        _extractedText = plateNumber ?? 'No license plate detected';
      });

      if (plateNumber == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'No license plate detected. Try another image or enter manually.'),
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
        _extractedText = 'Error scanning image';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
