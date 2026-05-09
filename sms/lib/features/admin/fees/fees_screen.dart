import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/attendance_service.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  final AttendanceService _service = AttendanceService();

  bool _isLoading = true;
  String _revenue = "AED 0k";
  String _outstanding = "AED 0k";
  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _fetchFinanceData();
  }

  Future<void> _fetchFinanceData() async {
    try {
      final data = await _service.getFinanceData();
      if (mounted) {
        setState(() {
          _revenue = data['revenue'];
          _outstanding = data['outstanding'];
          _payments = data['payments'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Optional: Show error snackbar
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
          // 1. REVENUE CARDS
          Row(
            children: [
              Expanded(
                child: _buildFinanceCard(
                  "Revenue",
                  _revenue,
                  Colors.green,
                  cardColor,
                  textColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFinanceCard(
                  "Outstanding",
                  _outstanding,
                  Colors.orange,
                  cardColor,
                  textColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 2. PAYMENT LIST HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Payment Status",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              IconButton(
                onPressed: _fetchFinanceData,
                icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. LIST OF STUDENTS
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child:
                _payments.isEmpty
                    ? Padding(
                      padding: const EdgeInsets.all(30),
                      child: Center(
                        child: Text(
                          "No data found",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                    )
                    : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _payments.length,
                      separatorBuilder:
                          (_, __) => Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : Colors.grey[100],
                          ),
                      itemBuilder: (context, index) {
                        final p = _payments[index];

                        Color statusColor;
                        String statusText = p['status'] ?? "Pending";

                        if (statusText == "Paid") {
                          statusColor = Colors.green;
                        } else if (statusText == "Pending") {
                          statusColor = Colors.orange;
                        } else {
                          statusColor = Colors.red;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey[200],
                                child: Text(
                                  (p['student'] != null &&
                                          p['student'].isNotEmpty)
                                      ? p['student'][0]
                                      : "?",
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Name & ID
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['student'] ?? "Unknown",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      "ID: ${p['id']}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Amount & Status
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    p['amount'],
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha:0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(width: 12),

                              // Action Icon (Reminder)
                              if (statusText != "Paid")
                                InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Reminder sent!"),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.send_rounded,
                                      size: 20,
                                      color: Colors.blue,
                                    ),
                                  ),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.check_circle,
                                    size: 20,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceCard(
    String title,
    String value,
    Color color,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.02),
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
}
