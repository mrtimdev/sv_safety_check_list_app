import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:safety_check_list/models/device_info.dart';
import '../models/category.dart';
import '../models/service_checker.dart';
import '../models/inspection.dart';

class ApiService {
  static const String baseUrl =
      'http://192.168.0.37:8081/api/v1'; // Update with your server IP
  static const String categoriesEndpoint = '/categories';
  static const String checklistsEndpoint = '/service-checkers';
  static const String uploadEndpoint =
      '/service-checkers/upload'; // You need to create this endpoint

  // Get categories from Spring API
  Future<List<Category>> getCategories() async {
    try {
      print('Fetching categories from: $baseUrl$categoriesEndpoint');
      final response = await http.get(
        Uri.parse('$baseUrl$categoriesEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Categories response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Categories data: $data');
        return data.map((json) => Category.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching categories: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }

  Future<String> uploadImage(File imageFile) async {
    try {
      print('Uploading image: ${imageFile.path}');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$uploadEndpoint'),
      );

      // ✅ Add image file (AUTO detect content type)
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', // must match @RequestParam("image")
          imageFile.path,
        ),
      );

      // Optional: add headers if needed
      request.headers.addAll({
        'Accept': 'application/json',
      });

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Upload response status: ${response.statusCode}');
      print('Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);

        return data['imageUrl'] ?? data['path'] ?? data['fileName'] ?? '';
      } else {
        throw Exception(
            'Failed to upload image: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Image upload failed: ${e.toString()}');
    }
  }

  // Create new checklist - Matches Spring Boot ServiceCheckerRequest
  Future<Map<String, dynamic>> createChecklist(
    Map<String, dynamic> data, {
    File? imageFile,
    required DeviceInfo deviceInfo,
  }) async {
    print('Creating checklist with data: $data');
    print('Image file: ${imageFile?.path}');
    print('Device Info: ${deviceInfo.toJson()}');

    try {
      // First upload image if exists
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await uploadImage(imageFile);
        // Add image URL to data if your API accepts it in JSON
        data['imagePath'] = imageUrl;
      }

      // Add device info to data
      data['deviceInfo'] = deviceInfo.toJson();

      final response = await http.post(
        Uri.parse('$baseUrl$checklistsEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );

      print('Create checklist response status: ${response.statusCode}');
      print('Create checklist response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 409) {
        // Conflict - checklist already exists
        final error = json.decode(response.body);
        throw Exception(error['error'] ??
            'Checklist already exists for this driver on this date');
      } else {
        throw Exception(
            'Failed to create checklist: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error creating checklist: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Alternative: Create checklist with multipart request (if API accepts form data)
  Future<Map<String, dynamic>> createChecklistWithImage(
    Map<String, dynamic> jsonData,
    File imageFile,
  ) async {
    try {
      print('Creating checklist with image using multipart');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$checklistsEndpoint/with-image'), // New endpoint
      );

      // Add JSON data as a field
      request.fields['data'] = json.encode(jsonData);

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Create with image response status: ${response.statusCode}');
      print('Create with image response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create checklist: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating checklist with image: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Update existing checklist
  Future<Map<String, dynamic>> updateChecklist(
    int id,
    Map<String, dynamic> data, {
    File? imageFile,
    required DeviceInfo deviceInfo,
  }) async {
    print('Updating checklist $id with data: $data');

    try {
      // Upload new image if exists
      if (imageFile != null) {
        String imageUrl = await uploadImage(imageFile);
        data['imagePath'] = imageUrl;
      }

      // Add device info to data
      data['deviceInfo'] = deviceInfo.toJson();

      final response = await http.put(
        Uri.parse('$baseUrl$checklistsEndpoint/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );

      print('Update checklist response status: ${response.statusCode}');
      print('Update checklist response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Checklist not found');
      } else {
        throw Exception(
            'Failed to update checklist: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error updating checklist: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Get all checklists with filters
  Future<Map<String, dynamic>> getChecklists({
    int page = 1,
    int limit = 20,
    String? dateFilter,
    int? driverId,
  }) async {
    try {
      String url = '$baseUrl$checklistsEndpoint/list?page=$page&limit=$limit';

      if (dateFilter != null) {
        url += '&dateFilter=$dateFilter';
      }

      if (driverId != null) {
        url += '&driverId=$driverId';
      }

      print('Fetching checklists from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Get checklists response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load checklists: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching checklists: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Get single checklist by ID
  Future<ServiceChecker> getChecklistById(int id) async {
    try {
      print('Fetching checklist $id from: $baseUrl$checklistsEndpoint/$id');

      final response = await http.get(
        Uri.parse('$baseUrl$checklistsEndpoint/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Get checklist response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ServiceChecker.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Checklist not found');
      } else {
        throw Exception('Failed to load checklist: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching checklist: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Delete checklist
  Future<void> deleteChecklist(int id) async {
    try {
      print('Deleting checklist $id');

      final response = await http.delete(
        Uri.parse('$baseUrl$checklistsEndpoint/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Delete checklist response status: ${response.statusCode}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete checklist: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting checklist: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // In lib/services/api_service.dart

  List<ServiceChecker> parseChecklistsFromResponse(
      Map<String, dynamic> response) {
    try {
      final List<dynamic> data = response['data'] ?? [];
      print("📊 Parsing ${data.length} checklists from response");

      return data.map((json) {
        print(
            "📄 Parsing checklist item: ${json['id']} - ${json['licensePlate']}");

        // Parse the service checker using the new model
        return ServiceChecker.fromJson(json);
      }).toList();
    } catch (e) {
      print('❌ Error parsing checklists: $e');
      print('Response data: $response');
      return [];
    }
  }
}
