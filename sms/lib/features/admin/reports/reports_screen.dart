import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/attendance_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AttendanceService _service = AttendanceService();

  bool _isLoading = true;
  String _occupancy = "--%";
  String _peakTime = "--:--";
  String _activeRoutes = "--/--";
  List<dynamic> _drivers = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _service.getReportsData();
      if (mounted) {
        setState(() {
          _occupancy = data['occupancy'];
          _peakTime = data['peak_time'];
          _activeRoutes = data['active_routes'];
          _drivers = data['drivers'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Fleet Utilization",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, color: Colors.grey),
                tooltip: "Export Report",
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Horizontal Stats Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatCard(
                  "Avg. Occupancy",
                  _occupancy,
                  Colors.blue,
                  cardColor,
                  textColor,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  "Peak Time",
                  _peakTime,
                  Colors.orange,
                  cardColor,
                  textColor,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  "Active Routes",
                  _activeRoutes,
                  Colors.green,
                  cardColor,
                  textColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- SECTION: DRIVER LIST ---
          Text(
            "Driver Status",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child:
                _drivers.isEmpty
                    ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          "No drivers found",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                    )
                    : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _drivers.length,
                      separatorBuilder:
                          (_, __) => Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : Colors.grey[100],
                          ),
                      itemBuilder: (context, index) {
                        final d = _drivers[index];
                        // Using real status from DB, falling back to dummy score
                        return _buildDriverRow(
                          d['name'],
                          d['status'], // "On Shift" or "Off Duty"
                          d['status'] == 'On Shift'
                              ? Colors.green
                              : Colors.grey,
                          isDark,
                        );
                      },
                    ),
          ),

          const SizedBox(height: 24),

          // --- SECTION: EXPORT DATA ---
          Text(
            "Export Data",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildExportBtn(
                Icons.table_chart_rounded,
                "Attendance",
                cardColor,
                textColor,
              ),
              _buildExportBtn(
                Icons.attach_money_rounded,
                "Financials",
                cardColor,
                textColor,
              ),
              _buildExportBtn(
                Icons.warning_amber_rounded,
                "Incidents",
                cardColor,
                textColor,
              ),
              _buildExportBtn(
                Icons.history_rounded,
                "Driver Logs",
                cardColor,
                textColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(top: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverRow(String name, String status, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportBtn(
    IconData icon,
    String label,
    Color bgColor,
    Color textColor,
  ) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Exporting... (Demo)")));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha:0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
