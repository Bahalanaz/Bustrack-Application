import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/attendance_service.dart';

class StudentDetailsScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentDetailsScreen({
    super.key, 
    required this.studentId, 
    required this.studentName
  });

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> with SingleTickerProviderStateMixin {
  final AttendanceService _service = AttendanceService();
  late TabController _tabController;
  late Future<Map<String, dynamic>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _detailsFuture = _service.getStudentDetails(widget.studentId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Student Profile", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600)),
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "Timeline"),
            Tab(text: "Fees & Finance"),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          // 1. Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Error
          if (snapshot.hasError) {
            return Center(child: Text("Error loading details", style: TextStyle(color: textColor)));
          }

          // 3. Data Loaded
          final data = snapshot.data!;
          final student = data['student'];
          final List<dynamic> history = data['attendance_history'];

          return TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: ATTENDANCE TIMELINE
              _buildTimelineTab(student, history, isDark, cardColor, textColor, subText),
              
              // TAB 2: FEES (Placeholder)
              _buildFeesTab(isDark, cardColor, textColor),
            ],
          );
        },
      ),
    );
  }

  // --- TAB 1: TIMELINE ---
  Widget _buildTimelineTab(Map<String, dynamic> student, List<dynamic> history, bool isDark, Color cardColor, Color textColor, Color? subText) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.withValues(alpha:0.1),
                  child: Text(
                    student['Student_Name'][0],
                    style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 16),
                Text(student['Student_Name'], style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                Text("ID: ${student['Student_ID']}", style: GoogleFonts.poppins(color: subText)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha:0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text("Bus: ${student['Assigned_Bus']}", style: GoogleFonts.poppins(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          Text("Recent Activity", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: subText)),
          const SizedBox(height: 16),

          // History List
          if (history.isEmpty)
             Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("No attendance records found.", style: TextStyle(color: subText)))),

          ...history.map((record) => _buildHistoryItem(record, cardColor, textColor, subText, isDark)),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> record, Color cardColor, Color textColor, Color? subText, bool isDark) {
    final isEntry = record['Scan_Type'] == 'Entry';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isEntry ? Colors.green.withValues(alpha:0.1) : Colors.orange.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(isEntry ? Icons.login : Icons.logout, color: isEntry ? Colors.green : Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEntry ? "Boarded Bus" : "Left Bus", 
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor)
                ),
                Text(record['Date'], style: GoogleFonts.poppins(fontSize: 12, color: subText)),
              ],
            ),
          ),
          Text(record['Time'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  // --- TAB 2: FEES (Placeholder) ---
  Widget _buildFeesTab(bool isDark, Color cardColor, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monetization_on_outlined, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("Fees Management", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          Text("Detailed fee history coming soon.", style: GoogleFonts.poppins(color: Colors.grey)),
        ],
      ),
    );
  }
}