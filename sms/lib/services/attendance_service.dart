import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// --- MODEL CLASS (UPDATED FOR NEW DATE FORMAT) ---
class AttendanceLog {
  final DateTime timestamp;
  final String busId;
  final bool isEntry;

  AttendanceLog({
    required this.timestamp,
    required this.busId,
    required this.isEntry,
  });

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    DateTime dt = DateTime.now();
    try {
      // 1. Handle the specific format from routes.py (Date + Time separated)
      if (json['Date'] != null && json['Time'] != null) {
        // Example: Date="2023-12-01", Time="02:30 PM"
        String dateTimeStr = "${json['Date']} ${json['Time']}";
        dt = DateFormat("yyyy-MM-dd h:mm a").parse(dateTimeStr);
      }
      // 2. Fallback for other formats
      else if (json['DateTime'] != null) {
        dt = DateFormat("yyyy-MM-dd h:mm:ss a").parse(json['DateTime']);
      }
    } catch (e) {
      debugPrint("Date Parsing Error: $e");
    }

    bool determineEntry() {
      if (json['Scan_Type'] != null) {
        return json['Scan_Type'] == 'Entry';
      }
      return dt.hour < 14;
    }

    return AttendanceLog(
      timestamp: dt,
      busId: json['Bus'] ?? 'UniBus',
      isEntry: determineEntry(),
    );
  }
}

// --- SERVICE CLASS ---
class AttendanceService {
  // ⚠️ IMPORTANT: Must match the IP used in your pi_scanner.py
  // If you change networks, update this IP!
  static const String baseUrl = 'http://192.168.8.18:5000';

  // ====================================================================
  //               SECTION 1: ADMIN - STUDENTS & LINKING (FIXED)
  // ====================================================================

  // 1. GET ALL STUDENTS
  Future<List<Map<String, dynamic>>> getAllStudents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Search_Student?name='),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> studentsJson = data['students'];

        return studentsJson.map((s) {
          return {
            'id': s['Student_ID'],
            'name': s['Student_Name'],
            'email': s['Email'] ?? '',
            'route': s['Locations'] ?? 'No Route',
            'status':
                (s['Card_ID'] != null && s['Card_ID'].toString().isNotEmpty)
                    ? 'Active'
                    : 'Pending',
            'image': _getInitials(s['Student_Name']),
            'nfc':
                (s['Card_ID'] != null && s['Card_ID'].toString().isNotEmpty)
                    ? 'Linked'
                    : 'Not Linked',
          };
        }).toList();
      } else {
        throw Exception('Failed to load students');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // 2. DELETE STUDENT
  Future<bool> deleteStudent(int studentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/Delete_Student/$studentId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // 3. CHECK PI CONNECTION (Heartbeat)
  Future<bool> isPiConnected() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/System_Status'));
      if (response.statusCode == 200) {
        return json.decode(response.body)['pi_connected'];
      }
    } catch (e) {
      // Silent fail
    }
    return false;
  }

  // 4. SET LINKING MODE
  Future<void> setLinkingMode(int? studentId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/Set_Linking_Mode'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'student_id': studentId}),
      );
    } catch (e) {
      debugPrint("Error setting linking mode: $e");
    }
  }

  // 5. MANUAL LINKING (Fallback)
  Future<bool> linkStudentCard(int studentId, String cardId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Assign_Card'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'student_id': studentId, 'card_id': cardId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // 6. POLL FOR RFID SCANS (Manual Mode)
  Future<String?> getLatestRfidScan() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/Get_Last_Scan'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['card_id'];
      }
    } catch (e) {
      // Silent error
    }
    return null;
  }

  // HELPER: Get Initials
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return "ST";
    List<String> parts = name.trim().split(" ");
    if (parts.length >= 2) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // ====================================================================
  //               SECTION 2: STUDENT APP - FIXED METHODS
  // ====================================================================

  // HELPER: Get Stored Student ID
  Future<int> _getStoredStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    // Assuming you saved 'student_id' during login.
    // If testing without login, this defaults to ID 1.
    return prefs.getInt('student_id') ?? 1;
  }

  // GET STUDENT PROFILE & DASHBOARD DATA
  Future<Map<String, dynamic>> getStudentProfile() async {
    try {
      final int id = await _getStoredStudentId();

      // Use the new Unified Endpoint
      final response = await http.get(
        Uri.parse('$baseUrl/Get_Student_Profile_And_Logs/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // GET ATTENDANCE HISTORY
  Future<List<AttendanceLog>> getHistory() async {
    try {
      final int id = await _getStoredStudentId();

      final response = await http.get(
        Uri.parse('$baseUrl/Get_Student_Profile_And_Logs/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> historyJson = data['attendance_history'];
        return historyJson.map((json) => AttendanceLog.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load history');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // SIMULATE SCAN (Button on Dashboard)
  Future<bool> simulateScan() async {
    try {
      final int id = await _getStoredStudentId();

      final response = await http.post(
        Uri.parse('$baseUrl/Record_Attendance'), // Point to new Logic
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'Student_ID': id}),
      );

      return response.statusCode == 201;
    } catch (e) {
      rethrow;
    }
  }

  // SUBMIT TRANSPORT REQUEST
  Future<bool> submitTransportRequest(DateTime date, String reason) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/student/request-transport'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'date': DateFormat('yyyy-MM-dd').format(date),
          'reason': reason,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // SUBMIT SUPPORT TICKET
  Future<bool> submitSupportTicket(String category, String description) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Submit_Report'), // Updated to match routes.py
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'Student_ID': await _getStoredStudentId(),
          'Category': category,
          'Description': description,
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // STUDENT: GET MY ACTIVITY
  Future<Map<String, dynamic>> getMyActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/student/my-activity'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load activity');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // GET STOPS FOR STUDENT SELECTION
  Future<List<dynamic>> getStudentStopsList() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    final response = await http.get(
      Uri.parse('$baseUrl/student/stops'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load stops');
  }

  // SELECT A STOP
  Future<void> selectStudentStop(int stopId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    final response = await http.post(
      Uri.parse('$baseUrl/student/select-stop'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'stop_id': stopId}),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error']);
    }
  }

  // ====================================================================
  //               SECTION 3: ADMIN - FLEET MANAGEMENT (RESTORED)
  // ====================================================================

  // ADMIN: GET TRANSPORT REQUESTS
  Future<List<Map<String, dynamic>>> getAdminTransportRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/transport-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load requests');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: GET SUPPORT TICKETS
  Future<List<Map<String, dynamic>>> getAdminSupportTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/support-tickets'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load tickets');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: GET DASHBOARD STATS
  Future<Map<String, dynamic>> getAdminDashboardStats() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load dashboard');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: GET SPECIFIC STUDENT DETAILS (Admin View)
  Future<Map<String, dynamic>> getStudentDetails(int studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/Get_Student_Profile_And_Logs/$studentId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load details');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: GET ALL BUSES
  Future<List<Map<String, dynamic>>> getBuses() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/fleet/buses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load buses');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: ADD BUS
  Future<bool> addBus(String plate, int capacity, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/fleet/bus'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'plate': plate,
          'capacity': capacity,
          'status': status,
        }),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        final err = json.decode(response.body)['error'] ?? 'Failed to add bus';
        throw Exception(err);
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: GET ALL DRIVERS
  Future<List<Map<String, dynamic>>> getDrivers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/fleet/drivers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load drivers');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: ADD DRIVER
  Future<bool> addDriver(String name, String phone, String license) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/fleet/driver'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        // UPDATED: Added 'status': 'On Duty' to the request body
        body: json.encode({
          'name': name,
          'phone': phone,
          'license': license,
          'status': 'On Shift',
        }),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        final err =
            json.decode(response.body)['error'] ?? 'Failed to add driver';
        throw Exception(err);
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: ASSIGN DRIVER TO BUS
  Future<bool> assignDriverToBus(int busId, String driverName) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/fleet/bus/assign-driver'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'bus_id': busId, 'driver_name': driverName}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final err =
            json.decode(response.body)['error'] ?? 'Failed to assign driver';
        throw Exception(err);
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: GET BUS DETAILS (Includes Passenger List)
  Future<Map<String, dynamic>> getBusDetails(int busId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/fleet/bus/$busId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load bus details');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: GET UNASSIGNED STUDENTS
  Future<List<Map<String, dynamic>>> getUnassignedStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/fleet/students/unassigned'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception('Failed to load students');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: BULK ASSIGN STUDENTS TO BUS
  Future<bool> bulkAssignStudents(int busId, List<int> studentIds) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/fleet/bus/assign-bulk'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'bus_id': busId, 'student_ids': studentIds}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final err =
            json.decode(response.body)['error'] ?? 'Failed to assign students';
        throw Exception(err);
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: RESPOND TO TRANSPORT REQUEST
  Future<bool> respondToRequest(
    int requestId,
    String status, {
    String? comment,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/request/$requestId/respond'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'status': status, 'comment': comment ?? ""}),
      );

      if (response.statusCode == 200) return true;
      throw Exception('Failed to update request');
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADMIN: RESOLVE TICKET
  Future<bool> resolveTicket(int ticketId, {String? comment}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/report/$ticketId/resolve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'comment': comment ?? ""}),
      );

      if (response.statusCode == 200) return true;
      throw Exception('Failed to resolve ticket');
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // GET ACTIVE ROUTES
  Future<List<dynamic>> getActiveRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/routes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load routes');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // GET ALL STOPS
  Future<List<dynamic>> getAllStops() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/stops'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load stops');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // ADD BUS STOP
  Future<bool> addBusStop(
    String name,
    String area,
    int busId,
    String time,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/stop'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'name': name,
          'area': area,
          'bus_id': busId,
          'time': time,
        }),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        final err = json.decode(response.body)['error'] ?? 'Failed to add stop';
        throw Exception(err);
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // GET BUS DROPDOWN LIST
  Future<List<dynamic>> getBusDropdownList() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/bus-list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load bus list');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // GET FINANCE DATA
  Future<Map<String, dynamic>> getFinanceData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    final response = await http.get(
      Uri.parse('$baseUrl/admin/finance'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load finance data');
  }

  // GET REPORTS OVERVIEW
  Future<Map<String, dynamic>> getReportsData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    // if (token == null) throw Exception('Not logged in');

    final response = await http.get(
      Uri.parse('$baseUrl/admin/reports/overview'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load report data');
  }
}
