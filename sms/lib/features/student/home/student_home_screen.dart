import 'dart:async'; // Required for Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/attendance_service.dart';
import 'support_screen.dart';
import 'request_transport_screen.dart';
import '../activity/student_activity_screen.dart';
import 'student_stop_selection_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final AttendanceService _service = AttendanceService();

  late Future<List<dynamic>> _dashboardData;
  Timer? _refreshTimer; // Variable for the auto-refresh timer

  @override
  void initState() {
    super.initState();
    _refreshData();

    // --- NEW: AUTO-REFRESH EVERY 5 SECONDS ---
    // This makes the screen update automatically when the Pi scans a card
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        // We call setState to trigger a rebuild with new future,
        // but silently (without showing loading spinner every time)
        setState(() {
          _dashboardData = Future.wait([
            _service.getStudentProfile(),
            _service.getHistory(),
          ]);
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // Stop timer when screen closes
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _dashboardData = Future.wait([
        _service.getStudentProfile(), // Index 0
        _service.getHistory(), // Index 1
      ]);
    });
  }

  Future<void> _launchMap(String locationName) async {
    final Uri googleMapsUrl = Uri.parse(
      "http://googleusercontent.com/maps.google.com/?q=${Uri.encodeComponent(locationName)}",
    );
    try {
      if (!await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Could not launch maps');
      }
    } catch (e) {
      if (!mounted) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Could not open maps")));
    }
  }

  Future<void> _callDriver(String phone) async {
    final Uri url = Uri.parse("tel:$phone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (!mounted) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch dialer")),
      );
    }
  }

  // Navigate to Stop Selection
  void _navigateToStopSelection() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentStopSelectionScreen(),
      ),
    );
    if (result == true) {
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF050505) : const Color(0xFFFAFAFA);
    final surfaceColor = isDark ? const Color(0xFF141414) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.grey[500] : Colors.grey[500];
    final accentBlue = const Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<List<dynamic>>(
          future: _dashboardData,
          builder: (context, snapshot) {
            // 1. Loading (Only shows on first load now)
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            // 2. Error
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Connection Error",
                      style: GoogleFonts.poppins(color: textColor),
                    ),
                    TextButton(
                      onPressed: _refreshData,
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              );
            }

            // 3. Data Loaded
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final profileData = snapshot.data![0];
            final historyLogs = snapshot.data![1] as List<AttendanceLog>;

            // Extract Data
            final studentInfo = profileData['student'];
            final String studentName = studentInfo['Student_Name'] ?? "Student";
            final String studentId = studentInfo['Student_ID'].toString();
            final String course = studentInfo['Course'] ?? "No Course";
            final String busId = studentInfo['Assigned_Bus'] ?? "N/A";
            final String busPlate = studentInfo['Bus_Plate'] ?? "N/A";

            final String location =
                studentInfo['Bus_Location'] ?? "Not Selected";
            final String pickupTime = studentInfo['Pickup_Time'] ?? "--:--";

            final String driverName =
                studentInfo['Driver_Name'] ?? "Unassigned";
            final String driverPhone = studentInfo['Driver_Phone'] ?? "";

            // Determine Status
            bool isOnBus = false;
            if (historyLogs.isNotEmpty) {
              isOnBus = historyLogs.first.isEntry;
            }

            return RefreshIndicator(
              onRefresh: () async => _refreshData(),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HEADER
                    _buildPremiumHeader(
                      context,
                      studentName,
                      textColor,
                      subTextColor,
                      isDark,
                    ),

                    const SizedBox(height: 28),

                    // 2. HERO ID CARD
                    _buildHeroIdCard(
                      context,
                      studentName,
                      studentId,
                      course,
                      isOnBus,
                      isDark,
                    ),

                    const SizedBox(height: 20),

                    // 3. TRANSPORT CARD
                    if (busId != "Unassigned")
                      _buildTransportCard(
                        busId,
                        busPlate,
                        driverName,
                        driverPhone,
                        surfaceColor,
                        textColor,
                        subTextColor,
                        isDark,
                      ),

                    const SizedBox(height: 32),

                    // 4. QUICK ACTIONS
                    Text(
                      "Quick Actions",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: subTextColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildLocationTile(
                      location,
                      pickupTime,
                      surfaceColor,
                      textColor,
                      subTextColor,
                      isDark,
                    ),

                    const SizedBox(height: 12),

                    // Grid Actions
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionTile(
                            title: "Request\nTransport",
                            icon: Icons.calendar_month_rounded,
                            color: Colors.orange,
                            surfaceColor: surfaceColor,
                            textColor: textColor,
                            isDark: isDark,
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const RequestTransportScreen(),
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: _buildActionTile(
                            title: "My\nActivity",
                            icon: Icons.history_edu_rounded,
                            color: Colors.purple,
                            surfaceColor: surfaceColor,
                            textColor: textColor,
                            isDark: isDark,
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const StudentActivityScreen(),
                                  ),
                                ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: _buildActionTile(
                            title: "Help &\nSupport",
                            icon: Icons.chat_bubble_outline_rounded,
                            color: accentBlue,
                            surfaceColor: surfaceColor,
                            textColor: textColor,
                            isDark: isDark,
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SupportScreen(),
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // 5. RECENT ACTIVITY
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Recent Scans",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: subTextColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: subTextColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (historyLogs.isEmpty)
                      _buildEmptyState(subTextColor)
                    else
                      ...historyLogs
                          .take(3)
                          .map(
                            (log) => _buildMinimalLogItem(
                              log,
                              textColor,
                              subTextColor,
                              surfaceColor,
                              isDark,
                            ),
                          ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildPremiumHeader(
    BuildContext context,
    String name,
    Color textColor,
    Color? subTextColor,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back,",
              style: GoogleFonts.poppins(color: subTextColor, fontSize: 14),
            ),
            Text(
              name.split(' ')[0],
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.heavyImpact();
            _showSOSDialog(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.red.withValues(alpha:0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.gpp_maybe_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  "SOS",
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroIdCard(
    BuildContext context,
    String name,
    String id,
    String course,
    bool isOnBus,
    bool isDark,
  ) {
    final activeGradient = const LinearGradient(
      colors: [Color(0xFF059669), Color(0xFF10B981)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final idleGradient = LinearGradient(
      colors:
          isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: () async {
        // --- MANUAL REFRESH ON TAP ---
        _refreshData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutExpo,
        width: double.infinity,
        height: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: isOnBus ? activeGradient : idleGradient,
          boxShadow: [
            BoxShadow(
              color: (isOnBus ? Colors.green : Colors.blue).withValues(alpha:0.3),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha:0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha:0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color:
                                    isOnBus
                                        ? Colors.greenAccent
                                        : Colors.white70,
                                shape: BoxShape.circle,
                                boxShadow:
                                    isOnBus
                                        ? [
                                          BoxShadow(
                                            color: Colors.greenAccent
                                                .withValues(alpha:0.8),
                                            blurRadius: 6,
                                          ),
                                        ]
                                        : [],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOnBus ? "ON BOARD" : "OFF BOARD",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.nfc_rounded,
                        color: Colors.white54,
                        size: 28,
                      ),
                    ],
                  ),
                  Center(
                    child: Text(
                      isOnBus ? "Tap to Refresh" : "Ready to Scan",
                      style: GoogleFonts.poppins(
                        color: Colors.white24,
                        fontSize: 12,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "ID: $id  •  $course",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportCard(
    String busId,
    String plate,
    String driver,
    String phone,
    Color surfaceColor,
    Color textColor,
    Color? subTextColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha:0.05)
                  : Colors.black.withValues(alpha:0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_bus, color: Colors.blue),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "My Transport",
                    style: GoogleFonts.poppins(
                      color: subTextColor,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    "$busId ($plate)",
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(
                      Icons.person,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Driver",
                        style: GoogleFonts.poppins(
                          color: subTextColor,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        driver,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (phone.isNotEmpty && phone != "N/A")
                IconButton(
                  onPressed: () => _callDriver(phone),
                  icon: const Icon(Icons.phone, color: Colors.green),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha:0.1),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile(
    String location,
    String time,
    Color surfaceColor,
    Color textColor,
    Color? subTextColor,
    bool isDark,
  ) {
    final isNotSelected =
        location == "Not Selected" || location == "Unknown Location";

    return InkWell(
      onTap: () {
        if (isNotSelected) {
          _navigateToStopSelection();
        } else {
          showModalBottomSheet(
            context: context,
            builder:
                (ctx) => Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.map),
                      title: const Text("View on Map"),
                      onTap: () {
                        Navigator.pop(ctx);
                        _launchMap(location);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_location_alt),
                      title: const Text("Change Bus Stop"),
                      onTap: () {
                        Navigator.pop(ctx);
                        _navigateToStopSelection();
                      },
                    ),
                  ],
                ),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withValues(alpha:0.05)
                    : Colors.black.withValues(alpha:0.03),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF3B82F6),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Assigned Pickup",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      if (!isNotSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            time,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isNotSelected ? Colors.orange : subTextColor,
                      fontWeight:
                          isNotSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isNotSelected ? Icons.add_circle_outline : Icons.more_vert,
              size: 20,
              color: subTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required Color color,
    required Color surfaceColor,
    required Color textColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withValues(alpha:0.05)
                    : Colors.black.withValues(alpha:0.03),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: textColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalLogItem(
    AttendanceLog log,
    Color textColor,
    Color? subTextColor,
    Color surfaceColor,
    bool isDark,
  ) {
    final isEntry = log.isEntry;
    final timeStr = DateFormat('h:mm a').format(log.timestamp);
    final accentColor =
        isEntry ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha:0.03) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accentColor.withValues(alpha:0.4), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEntry ? "Boarded Bus" : "Left Bus",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                Text(
                  "Bus ${log.busId}",
                  style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: subTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color? subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off, size: 30, color: subTextColor),
            const SizedBox(height: 8),
            Text(
              "No recent activity",
              style: GoogleFonts.poppins(color: subTextColor, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _showSOSDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red),
                const SizedBox(width: 10),
                Text(
                  "Emergency",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            content: Text(
              "Send live location to Security?",
              style: GoogleFonts.poppins(color: Colors.grey[400]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Security alerted."),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: Text(
                  "ALERT",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }
}
