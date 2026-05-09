import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// --- SERVICE & MODEL (Kept same as before) ---
// (Paste the full AttendanceLog and AttendanceService classes here from previous response)
// ... Or import them if you moved them to a separate file.
// For this single file usage, I assume they are imported or present above.

import '../../../services/attendance_service.dart'; // Ensure correct import

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final AttendanceService _service = AttendanceService();
  late Future<List<AttendanceLog>> _historyFuture;
  String _selectedFilter = "All";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Changed to return Future<void> for RefreshIndicator
  Future<void> _loadData() async {
    setState(() {
      _historyFuture = _service.getHistory();
    });
    await _historyFuture; // Wait for it to finish
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgGradient = LinearGradient(
      colors: [
        isDark ? const Color(0xFF0B0B0B) : const Color(0xFFF7F9FC),
        isDark ? const Color(0xFF111111) : const Color(0xFFEFF2F6),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildHeader(isDark),
              const SizedBox(height: 20),
              _buildFrostedFilters(isDark),
              const SizedBox(height: 26),

              // FUTURE BUILDER WRAPPED IN REFRESH INDICATOR
              Expanded(
                child: FutureBuilder<List<AttendanceLog>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: isDark ? Colors.white : Colors.blueAccent,
                        ),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red[400]),
                            const SizedBox(height: 16),
                            Text("Connection failed", style: GoogleFonts.poppins(color: Colors.grey)),
                            TextButton(onPressed: _loadData, child: const Text("Retry"))
                          ],
                        ),
                      );
                    }

                    final allHistory = snapshot.data ?? [];
                    final filteredHistory = allHistory.where((log) {
                      if (_selectedFilter == "Entries") return log.isEntry;
                      if (_selectedFilter == "Exits") return !log.isEntry;
                      return true;
                    }).toList();

                    // WRAP LIST IN REFRESH INDICATOR
                    return RefreshIndicator(
                      onRefresh: _loadData,
                      color: Colors.blueAccent,
                      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                      child: filteredHistory.isEmpty
                          ? Stack( // Stack required for RefreshIndicator to work on empty views
                              children: [
                                ListView(), // Invisible scrollable to allow pull-to-refresh
                                _buildEmpty(isDark),
                              ],
                            )
                          : _buildTimeline(filteredHistory, isDark),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Travel History",
                style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                "Pull down to refresh", // Updated text to hint at functionality
                style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha:0.05) : Colors.white.withValues(alpha:0.4),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: _loadData,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // ... (Keep _buildFrostedFilters, _buildTimeline, _dateHeader, _timelineItem, _buildEmpty, _dateKey EXACTLY THE SAME)
  // Just paste them here from the previous file.
  
  Widget _buildFrostedFilters(bool isDark) {
    final labels = ["All", "Entries", "Exits"];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: labels.map((label) {
          final selected = _selectedFilter == label;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: selected ? Colors.blueAccent : (isDark ? Colors.white10 : Colors.grey[200]),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeline(List<AttendanceLog> logs, bool isDark) {
    Map<String, List<AttendanceLog>> grouped = {};
    for (var log in logs) {
      final key = _dateKey(log.timestamp);
      grouped.putIfAbsent(key, () => []).add(log);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      physics: const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            Text(entry.key.toUpperCase(), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 14),
            ...entry.value.map((log) => _timelineItem(log, false, isDark))
          ],
        );
      }).toList(),
    );
  }

  Widget _timelineItem(AttendanceLog log, bool isLast, bool isDark) {
    final time = DateFormat("h:mm a").format(log.timestamp);
    final color = log.isEntry ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final label = log.isEntry ? "Bus Boarded" : "Bus Exited";

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(time, textAlign: TextAlign.right, style: GoogleFonts.poppins(color: Colors.grey))),
          const SizedBox(width: 16),
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
              Text("Bus #${log.busId}", style: GoogleFonts.poppins(color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(child: Text("No history", style: GoogleFonts.poppins(color: Colors.grey)));
  }

  String _dateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (DateTime(date.year, date.month, date.day) == today) return "Today";
    return DateFormat("MMMM d").format(date);
  }
}