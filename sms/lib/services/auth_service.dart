import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // <--- 1. IMPORT THIS FOR kIsWeb

class AuthService {
  // --- 2. SMART URL LOGIC ---
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000'; // For Chrome/Web
    } else {
      return 'http://10.0.2.2:5000'; // For Android Emulator
    }
  }

  // --- STUDENT LOGIN ---
  Future<Map<String, dynamic>> loginStudent(String emailOrUser, String password) async {
    final url = Uri.parse('$baseUrl/Login_Student');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Username_or_Email': emailOrUser,
          'Password': password,
        }),
      );

      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }

  // --- ADMIN LOGIN ---
  Future<Map<String, dynamic>> loginAdmin(String emailOrUser, String password) async {
    final url = Uri.parse('$baseUrl/Login_Admin');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Username_or_Email': emailOrUser,
          'Password': password,
        }),
      );
      return _processResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }

  // --- STUDENT SIGNUP ---
  Future<Map<String, dynamic>> signupStudent({
    required String name,
    required String username,
    required String email,
    required String password,
    required String phone,
    required String course,
    required String yearLevel,
  }) async {
    final url = Uri.parse('$baseUrl/Signup_Student');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Student_Name': name,
          'Student_Username': username,
          'Email': email,
          'Student_Password': password,
          'Student_Number': phone,
          'Course': course,
          'Year_Level': yearLevel,
          'Locations': 'Main Campus',
        }),
      );
      return _processResponse(response, successCode: 201);
    } catch (e) {
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }

  // --- ADMIN SIGNUP ---
  Future<Map<String, dynamic>> signupAdmin({
    required String name,
    required String username,
    required String email,
    required String password,
    required String phone,
  }) async {
    final url = Uri.parse('$baseUrl/Signup_Admin');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Admin_Name': name,
          'Admin_Username': username,
          'Email': email,
          'Admin_Password': password,
          'Admin_Number': phone,
        }),
      );
      return _processResponse(response, successCode: 201);
    } catch (e) {
      return {'success': false, 'message': 'Connection Error: $e'};
    }
  }

  // --- SUBMIT REPORT ---
  Future<bool> submitReport({
    required String studentId,
    required String category,
    required String description,
  }) async {
    final url = Uri.parse('$baseUrl/Submit_Report');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'Student_ID': studentId,
          'Category': category,
          'Description': description,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- RECORD ATTENDANCE ---
  Future<bool> recordAttendance(String studentId) async {
    final url = Uri.parse('$baseUrl/Record_Attendance');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'Student_ID': studentId}),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- GET HISTORY ---
  Future<Map<String, dynamic>> getAttendanceHistory(String studentId) async {
    final url = Uri.parse('$baseUrl/Get_Attendance/$studentId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'history': jsonDecode(response.body)['history']
        };
      }
      return {'success': false};
    } catch (e) {
      return {'success': false};
    }
  }

  // Helper
  Map<String, dynamic> _processResponse(http.Response response, {int successCode = 200}) {
    // Check if the response body is empty or not JSON
    if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
    }

    try {
      final data = jsonDecode(response.body);
      if (response.statusCode == successCode) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Request failed'};
    } catch (e) {
      return {'success': false, 'message': 'Invalid server response: ${response.statusCode}'};
    }
  }
}