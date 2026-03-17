import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:safety_check_list/models/device_info.dart';
import 'package:safety_check_list/models/login_request.dart';
import 'package:safety_check_list/units/jwt_helper.dart';
import 'package:safety_check_list/widgets/session_expired_popup.dart';
// import 'package:safety_check_list/models/service_checker_request.dart';
import '../models/category.dart';
import '../models/service_checker.dart';
import '../models/inspection.dart';
import '../services/secure_storage.dart';

class ApiService {
  // static const String homeUrl = 'http://192.168.0.114:8084';
  // static const String baseUrl = 'http://192.168.0.114:8084/api/v1';
  static const String homeUrl = 'http://45.201.196.19:8084';
  static const String baseUrl = 'http://45.201.196.19:8084/api/v1';
  // static const String homeUrl = 'http://172.20.10.4:8084';
  // static const String baseUrl = 'http://172.20.10.4:8084/api/v1';
  // 'http://45.201.196.19:8084/api/v1';
  static const String categoriesEndpoint = '/categories';
  static const String checklistsEndpoint = '/service-checkers';
  static const String uploadEndpoint = '/service-checkers/upload';

  // Helper method to get auth headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await SecureStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _handleResponse(http.Response response, {BuildContext? context}) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return json.decode(response.body);
      }
      return null;
    } else if (response.statusCode == 401) {
      if (context != null) {
        // Show popup immediately if context is provided
        SessionExpiredPopup.handleUnauthorized(context);
      }
      throw Exception(
          'SESSION_EXPIRED'); // Use a special message to identify session expiry
    } else if (response.statusCode == 403) {
      throw Exception('Forbidden: You don\'t have permission');
    } else {
      try {
        final error = json.decode(response.body);
        throw Exception(
          error['error'] ?? 'Request failed: ${response.statusCode}',
        );
      } catch (e) {
        throw Exception('Request failed: ${response.statusCode}');
      }
    }
  }

  // // Helper method to handle response
  // dynamic _handleResponse(http.Response response) {
  //   if (response.statusCode >= 200 && response.statusCode < 300) {
  //     if (response.body.isNotEmpty) {
  //       return json.decode(response.body);
  //     }
  //     return null;
  //   } else if (response.statusCode == 401) {
  //     throw Exception('Unauthorized: Please login again');
  //   } else if (response.statusCode == 403) {
  //     throw Exception('Forbidden: You don\'t have permission');
  //   } else {
  //     try {
  //       final error = json.decode(response.body);
  //       throw Exception(
  //         error['error'] ?? 'Request failed: ${response.statusCode}',
  //       );
  //     } catch (e) {
  //       throw Exception('Request failed: ${response.statusCode}');
  //     }
  //   }
  // }

  Future<List<Category>> getCategories({BuildContext? context}) async {
    try {
      print('Fetching categories from: $baseUrl$categoriesEndpoint');

      final headers = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl$categoriesEndpoint'),
        headers: headers,
      );

      print('Categories response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Categories data: $data');
        return data.map((json) => Category.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        // Handle session expired with popup
        if (context != null) {
          // Show the cool popup and navigate to login
          await SessionExpiredPopup.handleUnauthorized(
            context,
            message: 'ការប្រើប្រាស់របស់អ្នកបានផុតកំណត់',
          );
        }
        throw Exception('SESSION_EXPIRED');
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

      // Add auth token to headers
      final token = await SecureStorage.getToken();
      if (token != null) {
        request.headers.addAll({
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        });
      } else {
        request.headers.addAll({'Accept': 'application/json'});
      }

      // Add image file
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Upload response status: ${response.statusCode}');
      print('Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['imageUrl'] ?? data['path'] ?? data['fileName'] ?? '';
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to upload image: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Image upload failed: ${e.toString()}');
    }
  }

  // Create new checklist
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
        data['imagePath'] = imageUrl;
      }

      // Add device info to data
      data['deviceInfo'] = deviceInfo.toJson();

      final headers = await _getAuthHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl$checklistsEndpoint'),
        headers: headers,
        body: json.encode(data),
      );

      print('Create checklist response status: ${response.statusCode}');
      print('Create checklist response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 409) {
        final error = json.decode(response.body);
        throw Exception(
          error['error'] ??
              'Checklist already exists for this driver on this date',
        );
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to create checklist: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error creating checklist: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Alternative: Create checklist with multipart request
  Future<Map<String, dynamic>> createChecklistWithImage(
    Map<String, dynamic> jsonData,
    File imageFile,
  ) async {
    try {
      print('Creating checklist with image using multipart');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$checklistsEndpoint/with-image'),
      );

      // Add auth token to headers
      final token = await SecureStorage.getToken();
      if (token != null) {
        request.headers.addAll({'Authorization': 'Bearer $token'});
      }

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
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
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

      final headers = await _getAuthHeaders();

      final response = await http.put(
        Uri.parse('$baseUrl$checklistsEndpoint/$id'),
        headers: headers,
        body: json.encode(data),
      );

      print('Update checklist response status: ${response.statusCode}');
      print('Update checklist response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('Checklist not found');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to update checklist: ${response.statusCode} - ${response.body}',
        );
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
    required DeviceInfo deviceInfo,
    BuildContext? context,
  }) async {
    try {
      String url = '$baseUrl$checklistsEndpoint/list?page=$page&limit=$limit';

      if (dateFilter != null) {
        url += '&dateFilter=$dateFilter';
      }

      url += '&deviceId=${deviceInfo.deviceId}';

      print('Fetching checklists from: $url');

      final headers = await _getAuthHeaders();

      final response = await http.get(Uri.parse(url), headers: headers);

      print('Get checklists response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print("📦 Received checklists response: $data");
        return data;
      } else if (response.statusCode == 401) {
        // Handle session expired with popup
        if (context != null) {
          // Show the cool popup and navigate to login
          await SessionExpiredPopup.handleUnauthorized(
            context,
            message: 'ការប្រើប្រាស់របស់អ្នកបានផុតកំណត់',
          );
        }
        throw Exception('SESSION_EXPIRED');
      } else {
        throw Exception(
          'Failed to create checklist: ${response.statusCode} - ${response.body}',
        );
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

      final headers = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl$checklistsEndpoint/$id'),
        headers: headers,
      );

      print('Get checklist response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ServiceChecker.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Checklist not found');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
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

      final headers = await _getAuthHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl$checklistsEndpoint/$id'),
        headers: headers,
      );

      print('Delete checklist response status: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete checklist: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting checklist: $e');
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Parse checklists from response
  List<ServiceChecker> parseChecklistsFromResponse(
    Map<String, dynamic> response,
  ) {
    try {
      final List<dynamic> data = response['data'] ?? [];
      print("📊 Parsing ${data.length} checklists from response");

      return data.map((json) {
        print(
          "📄 Parsing checklist item: ${json['id']} - ${json['licensePlate']}",
        );
        return ServiceChecker.fromJson(json);
      }).toList();
    } catch (e) {
      print('❌ Error parsing checklists: $e');
      print('Response data: $response');
      return [];
    }
  }

  Future<String> getFullImageUrl(String imagePath) async {
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    return '$baseUrl$imagePath';
  }

  // Cancel checklist
  Future<void> cancelChecklist(int id, String reason) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await http.put(
        Uri.parse(
          '$baseUrl$checklistsEndpoint/$id/cancel?reason=${Uri.encodeComponent(reason)}',
        ),
        headers: headers,
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode != 200) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to cancel checklist');
      }
    } catch (e) {
      throw Exception('Error cancelling checklist: $e');
    }
  }

  // In api_service.dart, update your login method

  Future<LoginResponse> login(String identifier, String password) async {
    try {
      final request = LoginRequest(identifier: identifier, password: password);

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      print('📤 Login request: ${request.toJson()}');
      print('📥 Login response status: ${response.statusCode}');
      print('📥 Login response body: ${response.body}');

      final Map<String, dynamic> responseData = json.decode(response.body);
      final loginResponse = LoginResponse.fromJson(responseData);

      if (loginResponse.success && loginResponse.token != null) {
        JwtHelper.printTokenInfo(loginResponse.token!);

        await SecureStorage.saveToken(
          loginResponse.token!,
          expiresInSeconds: loginResponse.expiresIn ?? 3600,
        );

        // Save refresh token if available
        if (loginResponse.refreshToken != null) {
          await SecureStorage.saveRefreshToken(loginResponse.refreshToken!);
        }

        // Save user data
        if (loginResponse.user != null) {
          await SecureStorage.saveUser(loginResponse.user!);
        }

        // Save remember me preference
        await SecureStorage.saveRememberMe(true);

        print(
            '✅ Login successful, token expires in: ${loginResponse.expiresIn ?? 3600} seconds');
      }

      return loginResponse;
    } on SocketException {
      throw Exception('No internet connection. Please check your network.');
    } on HttpException {
      throw Exception('Server error. Please try again later.');
    } on FormatException {
      throw Exception('Invalid response format from server.');
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Get current user info
  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception('Failed to get user info');
      }
    } catch (e) {
      throw Exception('Error getting user info: $e');
    }
  }

  // Logout method
  Future<void> logout(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode != 200) {
        throw Exception('Logout failed');
      }
    } catch (e) {
      throw Exception('Error logging out: $e');
    }
  }

  Future<Map<String, dynamic>> detectPlateWithoutToken(File imageFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://0.0.0.0:8000/detect'),
    );

    // Add image file
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    // Send request
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to detect plate: ${response.body}');
    }
  }

  Future<void> downloadAnnotatedImage(String url, String savePath) async {
    var response = await http.get(Uri.parse('$baseUrl$url'));

    if (response.statusCode == 200) {
      File imageFile = File(savePath);
      await imageFile.writeAsBytes(response.bodyBytes);
    } else {
      throw Exception('Failed to download image');
    }
  }

  Future<String?> detectPlate(File imageFile) async {
    try {
      final String apiUrl = '$baseUrl/plates/detect';

      final headers = await _getAuthHeaders();

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // FIXED FIELD NAME
      request.files.add(
        await http.MultipartFile.fromPath(
          'image', // must match Spring @RequestParam("image")
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // FIXED HEADER
      request.headers.addAll(headers);
      request.headers['Accept'] = 'application/json';

      var streamedResponse = await request.send().timeout(
            const Duration(seconds: 30),
          );

      var resBody = await streamedResponse.stream.bytesToString();
      var jsonData = jsonDecode(resBody);

      print('📡 API Response: $jsonData');

      if (streamedResponse.statusCode == 200 && jsonData['success'] == true) {
        if (jsonData['results'] != null && jsonData['results'].isNotEmpty) {
          for (var result in jsonData['results']) {
            if (result['plate_text'] != null &&
                result['plate_text'].toString().isNotEmpty) {
              return cleanPlateText(
                result['display_text'] ?? result['plate_text'],
              );
            }
          }
        }

        if (jsonData['plates_detected'] > 0 && jsonData['plates_read'] == 0) {
          return null;
        }
      }

      return null;
    } catch (e) {
      if (e is SocketException) {
        throw Exception('មិនអាចភ្ជាប់ទៅម៉ាស៊ីនមេបានទេ។');
      } else if (e is TimeoutException) {
        throw Exception('ការតភ្ជាប់ផុតកំណត់។');
      } else {
        throw Exception('កំហុសក្នុងការតភ្ជាប់: $e');
      }
    }
  }

  String cleanPlateText(String text) {
    return text.replaceAll('-', '').replaceAll('.', '');
  }
}
