import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/attendance_service.dart'; // <--- Import Service

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AttendanceService _service = AttendanceService(); // <--- Service Instance
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _dashboardFuture = _service.getAdminDashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subText = isDark ? Colors.grey[400] : Colors.grey[500];

    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            // 1. Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(50.0),
                child: CircularProgressIndicator(),
              ));
            }
            // 2. Error State
            if (snapshot.hasError) {
              return Center(child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 10),
                  Text("Error loading dashboard", style: GoogleFonts.poppins(color: Colors.red)),
                  TextButton(onPressed: _refreshData, child: const Text("Retry"))
                ],
              ));
            }

            // 3. Data Loaded
            final data = snapshot.data!;
            final stats = data['stats'];
            final liveFeed = data['live_feed'] as List;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. DASHBOARD HEADER (Greeting & Search)
                _buildTopBar(data['date_str'], textColor, subText, cardColor, isDark),
                
                const SizedBox(height: 24),

                // 2. THE HERO CARD (Real Data)
                Text("Shift Status", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: subText)),
                const SizedBox(height: 12),
                _buildShiftHeroCard(stats, cardColor, textColor, isDark),

                const SizedBox(height: 24),

                // 3. LIVE FEED (Real Data)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Live Feed", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: subText)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha:0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text("LIVE", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                _buildLiveFeed(liveFeed, cardColor, textColor, subText, isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildTopBar(String dateStr, Color textColor, Color? subText, Color cardColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: GoogleFonts.poppins(fontSize: 12, color: subText, fontWeight: FontWeight.w500)),
                Text("Dashboard", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Search Bar (Visual Only for now)
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: subText),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Search ID or Bus...",
                    hintStyle: GoogleFonts.poppins(color: subText, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShiftHeroCard(Map<String, dynamic> stats, Color cardColor, Color textColor, bool isDark) {
    // Calculate progress percentage for circle
    double progress = (stats['progress'] as num).toDouble();
    int percent = (progress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB), 
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2563EB).withValues(alpha:0.3), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                height: 70, width: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress, 
                      backgroundColor: Colors.white.withValues(alpha:0.2), 
                      color: Colors.white, 
                      strokeWidth: 6
                    ),
                    Text("$percent%", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Checked In", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                    Text("${stats['present']} / ${stats['total_expected']}", 
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.15), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${stats['pending']} Pending", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Icon(Icons.people_alt_outlined, size: 14, color: Colors.white.withValues(alpha:0.8)),
                    const SizedBox(width: 4),
                    Text("Live Updates", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLiveFeed(List<dynamic> feed, Color cardColor, Color textColor, Color? subText, bool isDark) {
    if (feed.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text("No recent activity", style: GoogleFonts.poppins(color: subText))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: feed.asMap().entries.map((entry) {
          int index = entry.key;
          var item = entry.value;
          return Column(
            children: [
              _buildFeedItem(
                item['name'], 
                item['action'], 
                item['time'], 
                item['is_entry'], 
                textColor, 
                subText
              ),
              if (index != feed.length - 1) 
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[100]),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeedItem(String name, String action, String time, bool isEntry, Color textColor, Color? subText) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isEntry ? Colors.green.withValues(alpha:0.1) : Colors.orange.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(isEntry ? Icons.login : Icons.logout, size: 16, color: isEntry ? Colors.green : Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor, fontSize: 13)),
                Text(action, style: GoogleFonts.poppins(color: subText, fontSize: 11)),
              ],
            ),
          ),
          Text(time, style: GoogleFonts.poppins(color: subText, fontSize: 11)),
        ],
      ),
    );
  }
}