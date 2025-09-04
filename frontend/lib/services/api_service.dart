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
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Registration failed'};
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
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        // Save token and user info
        await saveToken(data['token']);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', data['user_id']);
        await prefs.setString('email', data['email']);
        await prefs.setString('organization', data['organization'] ?? '');
        
        return {
          'success': true,
          'token': data['token'],
          'user_id': data['user_id'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
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
      if  (token == null) {
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
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
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
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'co2_equivalent': data['co2_equivalent'],
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to add emission'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
}