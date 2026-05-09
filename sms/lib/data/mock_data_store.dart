import 'package:flutter/material.dart';
import '../shared/models/models.dart';
import '../services/auth_service.dart'; // <--- Import Service

class MockDataStore extends ChangeNotifier {
  final _authService = AuthService(); // <--- Instance

  // --- DATABASE ---
  final List<Bus> _buses = [
    Bus(
      id: 'B001',
      routeName: 'Route A - Downtown',
      driverName: 'John Smith',
      capacity: 30,
    ),
    Bus(
      id: 'B002',
      routeName: 'Route B - North Campus',
      driverName: 'Sarah Connor',
      capacity: 40,
    ),
  ];

  // Start with empty list (fetched from backend later)
  final List<Student> _students = [];

  // Start with empty logs
  List<AttendanceLog> _logs = [];

  // --- CURRENT USER SESSION ---
  String currentStudentId = '';

  // --- GETTERS ---
  List<Bus> get buses => _buses;
  List<Student> get students => _students;
  List<AttendanceLog> get logs => _logs;

  int get totalStudents => _students.length;
  int get totalBuses => _buses.length;

  // Count active scans from today
  int get activeScansToday =>
      _logs.where((l) {
        final now = DateTime.now();
        return l.timestamp.year == now.year &&
            l.timestamp.month == now.month &&
            l.timestamp.day == now.day;
      }).length;

  List<AttendanceLog> getMyHistory() {
    return _logs;
  }

  Student? get currentUser {
    try {
      return _students.firstWhere((s) => s.id == currentStudentId);
    } catch (e) {
      return null;
    }
  }

  // --- ACTIONS ---

  // 1. Save Real User & Fetch History
  void setRealUser(Map<String, dynamic> apiData) {
    final s = apiData.containsKey('student') ? apiData['student'] : apiData;

    final realStudent = Student(
      id: s['ID'].toString(),
      name: s['Name'],
      course: s['Course'] ?? "Unassigned",
      email: s['Email'],
      yearLevel: s['Year_Level'] ?? "Year 1",
      rfidCardId: null,
      assignedBusId: null,
    );

    _students.clear(); // Clear fake data
    _students.add(realStudent);
    currentStudentId = realStudent.id;

    // Fetch History immediately after login
    _fetchRealHistory();

    notifyListeners();
  }

  // 2. Fetch Real History from Python (FIXED: TRUST BACKEND)
  Future<void> _fetchRealHistory() async {
    if (currentStudentId.isEmpty) return;

    final result = await _authService.getAttendanceHistory(currentStudentId);

    if (result['success']) {
      List<dynamic> historyData = result['history'];

      List<AttendanceLog> tempLogs = [];

      for (var log in historyData) {
        // --- FIX: Trust the backend's "Type" ---
        // The backend sends "Entry" or "Exit". We use that directly.
        bool isEntry = (log['Type'] == 'Entry');

        tempLogs.add(
          AttendanceLog(
            id: log['Attendance_ID'].toString(),
            studentId: currentStudentId,
            busId: "B001", // You can update this later if backend sends Bus ID
            timestamp: DateTime.parse(log['Time']),
            isEntry: isEntry,
          ),
        );
      }

      // The backend usually sends newest first.
      // If backend sends Newest -> Oldest, we just assign it.
      // If backend sends Oldest -> Newest, we use .reversed.toList().
      // Your current backend code: .order_by(Attendance.Time_Scanned_Date.desc())
      // This means the Backend sends Newest First. So we do NOT need to reverse it.

      _logs = tempLogs;

      notifyListeners();
    }
  }

  // 3. Simulate Tap (Now sends to Backend)
  Future<void> simulateTap(String busId, bool isEntry) async {
    if (currentStudentId.isEmpty) return;

    // Call Backend
    final success = await _authService.recordAttendance(currentStudentId);

    if (success) {
      // Refresh the list from server to confirm it saved
      await _fetchRealHistory();
    }
  }

  // --- ADMIN ACTIONS (Keep these for UI demo) ---

  void addStudent(String name, String id) {
    _students.add(
      Student(
        id: id,
        name: name,
        course: 'Foundation',
        email: '$id@uni.ac.ae',
        yearLevel: 'Year 1',
      ),
    );
    notifyListeners();
  }

  void updateStudent(String originalId, String newName, String newId) {
    final index = _students.indexWhere((s) => s.id == originalId);
    if (index != -1) {
      final old = _students[index];
      _students[index] = Student(
        id: newId,
        name: newName,
        course: old.course,
        email: old.email,
        yearLevel: old.yearLevel,
      );
      notifyListeners();
    }
  }

  void deleteStudent(String id) {
    _students.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  void assignCard(String studentId) {
    final index = _students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      _students[index].rfidCardId =
          "UID_${DateTime.now().millisecondsSinceEpoch}";
      notifyListeners();
    }
  }
}
