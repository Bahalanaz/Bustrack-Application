import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async'; // Required for Timer/Delay
import '../../../services/attendance_service.dart';
import 'student_details_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final AttendanceService _service = AttendanceService();

  // State for Data
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredList = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter State
  String _searchQuery = "";
  String _filterStatus = "All"; // All, Active, Blocked

  // --- NEW: SCANNER STATUS STATE ---
  bool _isScannerOnline = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _fetchStudents();

    // Check Scanner Status every 5 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      bool online = await _service.isPiConnected();
      if (mounted) {
        setState(() => _isScannerOnline = online);
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  // 1. Fetch Real Data
  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await _service.getAllStudents();
      setState(() {
        _allStudents = students;
        _filteredList = students; // Initial sync
        _isLoading = false;
      });
      _runFilter(); // Re-apply filters
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // 2. Filter Logic (Search + Status)
  void _runFilter() {
    setState(() {
      _filteredList =
          _allStudents.where((s) {
            final matchesSearch =
                s['name'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                s['id'].toString().contains(_searchQuery);
            final matchesFilter =
                _filterStatus == "All" || s['status'] == _filterStatus;
            return matchesSearch && matchesFilter;
          }).toList();
    });
  }

  // --- ACTIONS ---

  // A. AUTO-LINK CARD DIALOG (Updated Logic)
  void _showLinkCardDialog(int studentId, String name) async {
    // 1. Tell Backend to start "Linking Mode" for this student
    await _service.setLinkingMode(studentId);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false, // User must click Cancel to stop
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.nfc, color: Colors.blue),
              const SizedBox(width: 10),
              const Text("Linking Mode"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animation
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha:0.1),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),

              // Instructions
              Text(
                "Scan Card Now",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Scan card on the Admin Reader now...", // Changed this
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // CANCEL: Tell backend to stop linking mode
                final nav = Navigator.of(ctx);
                await _service.setLinkingMode(null);
                nav.pop();
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    // 2. Poll for Success (Wait for Backend to say "Linked")
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    bool linked = false;
    while (!linked && mounted) {
      await Future.delayed(const Duration(seconds: 1));

      // We re-fetch the list silently to check for updates
      try {
        final latestData = await _service.getAllStudents();
        var updatedStudent = latestData.firstWhere(
          (s) => s['id'] == studentId,
          orElse: () => {},
        );

        if (updatedStudent.isNotEmpty && updatedStudent['nfc'] == 'Linked') {
          linked = true;
          if (mounted) {
            // Close Dialog
            navigator.pop();
            // Show Success Message
            messenger.showSnackBar(
              SnackBar(
                content: Text("✅ Card Successfully Linked to $name!"),
                backgroundColor: Colors.green,
              ),
            );
            // Update UI
            setState(() {
              _allStudents = latestData;
              _runFilter();
            });
          }
        }
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    }
  }

  // B. Delete Confirmation
  void _confirmDelete(int studentId, String name) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Delete Student?"),
            content: Text(
              "Are you sure you want to delete $name? This action cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(ctx);
                  Navigator.pop(ctx);
                  try {
                    await _service.deleteStudent(studentId);
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Student Deleted")),
                    );
                    _fetchStudents(); // Refresh list
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      children: [
        // 1. TOP CONTROLS SECTION
        Container(
          padding: const EdgeInsets.all(20),
          color: cardColor,
          child: Column(
            children: [
              // Row 1: Search + Status Indicator
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) {
                        _searchQuery = val;
                        _runFilter();
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        hintText: "Search Name or ID...",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // --- NEW: SCANNER STATUS DOT ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _isScannerOnline
                              ? Colors.green.withValues(alpha:0.1)
                              : Colors.red.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isScannerOnline ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: _isScannerOnline ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isScannerOnline ? "Online" : "Offline",
                          style: TextStyle(
                            color: _isScannerOnline ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Row 2: Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("All", isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip("Active", isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip("Blocked", isDark),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. STUDENT LIST
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                    child: Text(
                      "Error: $_errorMessage",
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                  : _filteredList.isEmpty
                  ? Center(
                    child: Text(
                      "No students found",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final student = _filteredList[index];
                      return _buildStudentCard(
                        student,
                        cardColor,
                        textColor,
                        isDark,
                      );
                    },
                  ),
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _buildFilterChip(String label, bool isDark) {
    final isSelected = _filterStatus == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _filterStatus = label;
          _runFilter();
        });
      },
      selectedColor: Colors.blue.withValues(alpha:0.15),
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      labelStyle: GoogleFonts.poppins(
        color:
            isSelected
                ? Colors.blue
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildStudentCard(
    Map<String, dynamic> student,
    Color cardColor,
    Color textColor,
    bool isDark,
  ) {
    final isActive = student['status'] == "Active";

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => StudentDetailsScreen(
                  studentId: student['id'],
                  studentName: student['name'],
                ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  isActive
                      ? Colors.blue.withValues(alpha:0.1)
                      : Colors.grey.withValues(alpha:0.1),
              child: Text(
                student['image'],
                style: TextStyle(
                  color: isActive ? Colors.blue : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['name'],
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "ID: ${student['id']}",
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      student['route'],
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: textColor.withValues(alpha:0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Status & Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isActive
                            ? Colors.green.withValues(alpha:0.1)
                            : Colors.red.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    student['status'],
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      color: isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ACTION MENU
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  onSelected: (value) {
                    if (value == 'link') {
                      _showLinkCardDialog(student['id'], student['name']);
                    } else if (value == 'delete') {
                      _confirmDelete(student['id'], student['name']);
                    }
                  },
                  itemBuilder:
                      (BuildContext context) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'link',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.nfc,
                                size: 18,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                student['nfc'] == 'Linked'
                                    ? 'Update Card'
                                    : 'Link Card',
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 10),
                              Text(
                                'Delete Student',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
