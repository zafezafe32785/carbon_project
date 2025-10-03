import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  // Get saved token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
  
  // Save token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }
  
  // Clear token (logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  
  // Test API Connection
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse(Constants.baseUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
  
  // Register
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    required String organization,
    String? phoneNum,
  }) async {
    try {
      print('Attempting registration for: $email');
      
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'username': username,
          'company_name': organization,
          'phone_num': phoneNum ?? '',
        }),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      try {
        final data = json.decode(response.body);

        if (response.statusCode == 201) {
          return {'success': true, 'message': data['message'] ?? 'Registration successful'};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Registration failed'};
        }
      } on FormatException catch (e) {
        print('JSON parsing error: $e');
        return {'success': false, 'message': 'Invalid server response'};
      }
    } catch (e) {
      print('Registration error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
  
  // Login
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      print('API Login - Email: $email');
      
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
      
      print('API Login - Status Code: ${response.statusCode}');
      print('API Login - Response Body: ${response.body}');

      try {
        final data = json.decode(response.body);

        if (response.statusCode == 200) {
          // Validate required fields exist
          if (data['token'] == null || data['user_id'] == null) {
            return {'success': false, 'message': 'Invalid server response: missing token or user_id'};
          }

          // Save token and user info
          await saveToken(data['token']);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', data['user_id']);
          await prefs.setString('email', data['email'] ?? '');
          await prefs.setString('organization', data['organization'] ?? '');

          return {
            'success': true,
            'token': data['token'],
            'user_id': data['user_id'],
          };
        } else {
          return {'success': false, 'message': data['message'] ?? 'Login failed'};
        }
      } on FormatException catch (e) {
        print('JSON parsing error: $e');
        return {'success': false, 'message': 'Invalid server response'};
      }
    } catch (e) {
      print('Login error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
  
  // Get Dashboard Data
  static Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Dashboard response status: ${response.statusCode}');
      print('Dashboard response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          return {
            'success': true,
            'data': data,
          };
        } on FormatException catch (e) {
          print('JSON parsing error: $e');
          return {'success': false, 'message': 'Invalid server response'};
        }
      } else if (response.statusCode == 401) {
        // Don't automatically clear token on 401, let the user decide
        return {'success': false, 'message': 'Session expired'};
      } else {
        return {'success': false, 'message': 'Failed to load dashboard'};
      }
    } catch (e) {
      print('Dashboard error: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
  
  // Add Emission
  static Future<Map<String, dynamic>> addEmission({
    required String category,
    required double amount,
    required String unit,
    required int month,
    required int year,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/emissions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'category': category,
          'amount': amount,
          'unit': unit,
          'month': month,
          'year': year,
        }),
      );

      try {
        final data = json.decode(response.body);

        if (response.statusCode == 201) {
          return {
            'success': true,
            'message': data['message'] ?? 'Emission added successfully',
            'co2_equivalent': data['co2_equivalent'],
          };
        } else {
          return {'success': false, 'message': data['message'] ?? 'Failed to add emission'};
        }
      } on FormatException catch (e) {
        print('JSON parsing error: $e');
        return {'success': false, 'message': 'Invalid server response'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Generic GET method
  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      try {
        final data = json.decode(response.body);

        if (response.statusCode == 200) {
          return data;
        } else {
          return {'success': false, 'message': data['message'] ?? 'Request failed'};
        }
      } on FormatException catch (e) {
        print('JSON parsing error in GET: $e');
        return {'success': false, 'message': 'Invalid server response'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Generic POST method
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      try {
        final data = json.decode(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          return data;
        } else {
          return {'success': false, 'message': data['message'] ?? 'Request failed'};
        }
      } on FormatException catch (e) {
        print('JSON parsing error in POST: $e');
        return {'success': false, 'message': 'Invalid server response'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Admin API Methods
  
  // Get all users (admin only)
  static Future<Map<String, dynamic>> getUsers() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/admin/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      try {
        final data = json.decode(response.body);

        if (response.statusCode == 200) {
          return {'success': true, 'data': data['users']};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Failed to load users'};
        }
      } on FormatException catch (e) {
        print('JSON parsing error: $e');
        return {'success': false, 'message': 'Invalid server response'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get audit logs (admin only)
  static Future<Map<String, dynamic>> getAuditLogs() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/admin/audit-logs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['logs']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load audit logs'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create user (admin only)
  static Future<Map<String, dynamic>> createUser(String username, String email, String password, bool isAdmin) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/admin/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'is_admin': isAdmin,
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to create user'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Update user admin status (admin only)
  static Future<Map<String, dynamic>> updateUserAdminStatus(int userId, bool isAdmin) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final response = await http.put(
        Uri.parse('${Constants.apiUrl}/admin/users/$userId/admin-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'is_admin': isAdmin,
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update user'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Reset user password (admin only)
  static Future<Map<String, dynamic>> resetUserPassword(int userId, String newPassword) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final response = await http.put(
        Uri.parse('${Constants.apiUrl}/admin/users/$userId/reset-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'new_password': newPassword,
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to reset password'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Delete user (admin only)
  static Future<Map<String, dynamic>> deleteUser(int userId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final response = await http.delete(
        Uri.parse('${Constants.apiUrl}/admin/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to delete user'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Edit Request API Methods
  
  // Get user's emissions records
  static Future<Map<String, dynamic>> getEmissions() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/emissions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load emissions'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Create edit request
  static Future<Map<String, dynamic>> createEditRequest({
    required String recordId,
    required String requestType, // 'edit' or 'delete'
    required String reason,
    Map<String, dynamic>? proposedChanges,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final requestBody = <String, dynamic>{
        'record_id': recordId,
        'request_type': requestType,
        'reason': reason,
      };
      
      if (proposedChanges != null) {
        requestBody['proposed_changes'] = proposedChanges;
      }
      
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/edit-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to create request'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get user's edit requests
  static Future<Map<String, dynamic>> getEditRequests({String? status}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      String url = '${Constants.apiUrl}/edit-requests';
      if (status != null) {
        url += '?status=$status';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load requests'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get all edit requests (admin only)
  static Future<Map<String, dynamic>> getAllEditRequests({String? status}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      String url = '${Constants.apiUrl}/admin/edit-requests';
      if (status != null) {
        url += '?status=$status';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load requests'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Approve edit request (admin only)
  static Future<Map<String, dynamic>> approveEditRequest(String requestId, {String? adminNotes}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final requestBody = <String, dynamic>{};
      if (adminNotes != null) {
        requestBody['admin_notes'] = adminNotes;
      }
      
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/admin/edit-requests/$requestId/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to approve request'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Reject edit request (admin only)
  static Future<Map<String, dynamic>> rejectEditRequest(String requestId, {String? rejectionReason, String? adminNotes}) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }
      
      final requestBody = <String, dynamic>{};
      if (rejectionReason != null) {
        requestBody['rejection_reason'] = rejectionReason;
      }
      if (adminNotes != null) {
        requestBody['admin_notes'] = adminNotes;
      }
      
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/admin/edit-requests/$requestId/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to reject request'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}
