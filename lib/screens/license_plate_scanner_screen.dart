import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/loading_indicator.dart';
import 'package:http/http.dart' as http;

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

  static const Color primaryColor = Color(0xFF1E3A8A);

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('ស្កេនលេខផ្លាករថយន្ត',
            style: TextStyle(color: Colors.white)),
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
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
                              _extractedText ?? '',
                              _extractedTextEstimated,
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
                                  _extractedText,
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
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;

      final image =
          await decodeImageFromList(File(imageFile.path).readAsBytesSync());
      final double imageWidth = image.width.toDouble();
      final double imageHeight = image.height.toDouble();

      final Rect targetRegion = Rect.fromLTWH(
        0.0,
        0.0,
        imageWidth,
        imageHeight,
      );

      StringBuffer filteredTextBuffer = StringBuffer();

      for (TextBlock block in recognizedText.blocks) {
        if (targetRegion.overlaps(block.boundingBox)) {
          for (TextLine line in block.lines) {
            if (targetRegion.overlaps(line.boundingBox)) {
              filteredTextBuffer.writeln(line.text);
            }
          }
        }
      }

      final String scannedTextInRegion = filteredTextBuffer.toString().trim();
      debugPrint("Scanned text in region: \n$scannedTextInRegion");

      setState(() {
        _extractedTextEstimated = scannedTextInRegion;
      });

      String? plateNumber;
      List<String> lines = scannedTextInRegion.split('\n');

      for (String line in lines) {
        String text = line.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();

        if (text.length >= 4 && text.length <= 8) {
          if (RegExp(r'^[A-Z]{2,4}[0-9]{2,4}$').hasMatch(text) ||
              RegExp(r'^[0-9]{2,4}[A-Z]{2,4}$').hasMatch(text)) {
            plateNumber = text;
            break;
          }
        }

        if (line.contains('-')) {
          String possiblePlate = line.replaceAll(' ', '').toUpperCase();
          if (RegExp(r'^[A-Z]{2,3}-\d{3,4}$').hasMatch(possiblePlate)) {
            plateNumber = possiblePlate;
            break;
          }
        }
      }

      setState(() {
        _isProcessing = false;
        _extractedText = plateNumber ?? 'រកមិនឃើញផ្លាកលេខរថយន្តទេ';
      });

      if (plateNumber == null) {
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
        _extractedText = 'Error scanning image';
        _extractedTextEstimated = null;
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

  Future<ui.Image> decodeImageFromList(List<int> bytes) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(Uint8List.fromList(bytes), (ui.Image img) {
      return completer.complete(img);
    });
    return completer.future;
  }

  Future<String?> detectPlate(File imageFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://0.0.0.0:8000/detect '),
    );

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    var response = await request.send();
    var resBody = await response.stream.bytesToString();

    var jsonData = jsonDecode(resBody);

    if (jsonData['plates'].length > 0) {
      return jsonData['plates'][0];
    }

    return null;
  }
}
