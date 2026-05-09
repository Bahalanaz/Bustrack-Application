// lib/shared/models/models.dart

// 1. Student Model
class Student {
  final String id;
  final String name;
  final String course; // <--- NEW
  final String email; // <--- NEW
  final String yearLevel; // <--- NEW
  String? rfidCardId; // Can be null if no card assigned
  String? assignedBusId; // Can be null if no bus assigned
  bool isActive;

  Student({
    required this.id,
    required this.name,
    required this.course, // <--- NEW
    required this.email, // <--- NEW
    required this.yearLevel, // <--- NEW
    this.rfidCardId,
    this.assignedBusId,
    this.isActive = true,
  });
}

// 2. Bus Model
class Bus {
  final String id;
  final String routeName;
  final String driverName;
  final int capacity;

  Bus({
    required this.id,
    required this.routeName,
    required this.driverName,
    required this.capacity,
  });
}

// 3. Attendance Log Model
class AttendanceLog {
  final String id;
  final String studentId;
  final String busId;
  final DateTime timestamp;
  final bool isEntry; // true = Enter, false = Exit
  bool isFlagged; // true if scanned on wrong bus/time

  AttendanceLog({
    required this.id,
    required this.studentId,
    required this.busId,
    required this.timestamp,
    required this.isEntry,
    this.isFlagged = false,
  });
}
