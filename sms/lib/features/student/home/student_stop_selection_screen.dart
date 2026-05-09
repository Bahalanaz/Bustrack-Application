import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/attendance_service.dart';

class StudentStopSelectionScreen extends StatefulWidget {
  const StudentStopSelectionScreen({super.key});

  @override
  State<StudentStopSelectionScreen> createState() =>
      _StudentStopSelectionScreenState();
}

class _StudentStopSelectionScreenState
    extends State<StudentStopSelectionScreen> {
  final AttendanceService _service = AttendanceService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allStops = [];
  List<dynamic> _filteredStops = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchStops();
    _searchController.addListener(_filterStops);
  }

  Future<void> _fetchStops() async {
    try {
      final data = await _service.getStudentStopsList();
      if (mounted) {
        setState(() {
          _allStops = data;
          _filteredStops = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Silently fail or show simple error
      }
    }
  }

  void _filterStops() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStops =
          _allStops.where((stop) {
            final name = stop['name'].toString().toLowerCase();
            final area = stop['area'].toString().toLowerCase();
            return name.contains(query) || area.contains(query);
          }).toList();
    });
  }

  Future<void> _selectStop(int stopId, String stopName, String busInfo) async {
    // Confirm Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              "Confirm Selection",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Text(
              "Select '$stopName'?\n\nThis will automatically assign you to $busInfo.",
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Confirm"),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      await _service.selectStudentStop(stopId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bus assigned successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to refresh previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed: ${e.toString().replaceAll('Exception:', '')}",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "Select Pick-up Point",
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Container(
            padding: const EdgeInsets.all(16),
            color: cardColor,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search area (e.g. 'DSO', 'Deira')",
                hintStyle: GoogleFonts.poppins(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // LIST
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredStops.isEmpty
                    ? Center(
                      child: Text(
                        "No stops found.",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    )
                    : Stack(
                      children: [
                        ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredStops.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final stop = _filteredStops[index];
                            return _buildStopCard(
                              stop,
                              isDark,
                              cardColor,
                              textColor,
                            );
                          },
                        ),
                        if (_isSubmitting)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopCard(
    Map<String, dynamic> stop,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return InkWell(
      onTap: () => _selectStop(stop['id'], stop['name'], stop['bus_info']),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.place_rounded, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop['name'],
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.map, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        stop['area'],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time_filled,
                        size: 12,
                        color: Colors.orange[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stop['time'] ?? "07:00 AM",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
