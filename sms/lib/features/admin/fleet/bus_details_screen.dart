import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/attendance_service.dart';

class BusDetailsScreen extends StatefulWidget {
  final int busId;
  final String busName; // e.g. "B001"

  const BusDetailsScreen({
    super.key,
    required this.busId,
    required this.busName,
  });

  @override
  State<BusDetailsScreen> createState() => _BusDetailsScreenState();
}

class _BusDetailsScreenState extends State<BusDetailsScreen> {
  final AttendanceService _service = AttendanceService();

  bool _isLoading = true;
  Map<String, dynamic>? _busData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  // 1. Fetch Bus Details (incl. Passengers)
  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getBusDetails(widget.busId);
      setState(() {
        _busData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // 2. Open Bulk Assignment Dialog
  void _showAddStudentsDialog() async {
    // A. Fetch unassigned students first
    List<Map<String, dynamic>> unassigned = [];
    try {
      unassigned = await _service.getUnassignedStudents();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
      return;
    }

    if (unassigned.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No unassigned students found.")),
      );
      return;
    }

    // B. Show Dialog
    List<int> selectedIds = [];

    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  "Add Students",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: Column(
                    children: [
                      Text(
                        "Select students to add to ${widget.busName}:",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: unassigned.length,
                          itemBuilder: (context, index) {
                            final s = unassigned[index];
                            final isSelected = selectedIds.contains(s['id']);

                            return CheckboxListTile(
                              value: isSelected,
                              title: Text(
                                s['name'],
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                              subtitle: Text(
                                s['location'] ?? "No Location",
                                style: GoogleFonts.poppins(fontSize: 11),
                              ),
                              activeColor: Colors.blue,
                              onChanged: (bool? val) {
                                setDialogState(() {
                                  if (val == true) {
                                    selectedIds.add(s['id']);
                                  } else {
                                    selectedIds.remove(s['id']);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedIds.isEmpty) return;
                      Navigator.pop(ctx);

                      try {
                        await _service.bulkAssignStudents(
                          widget.busId,
                          selectedIds,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Added ${selectedIds.length} students",
                            ),
                          ),
                        );
                        _fetchDetails(); // Refresh Page
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Error: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Text("Add (${selectedIds.length})"),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.busName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.busName)),
        body: Center(child: Text("Error: $_errorMessage")),
      );
    }

    final passengers = _busData!['passengers'] as List;
    final int capacity = _busData!['capacity'];
    final int currentLoad = _busData!['current_load'];
    final double loadPercent = (currentLoad / capacity).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Bus Details: ${widget.busName}",
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentsDialog,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.group_add, color: Colors.white),
        label: const Text(
          "Add Students",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. INFO CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.blue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _busData!['plate'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          Text(
                            "Driver: ${_busData!['driver']}",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _busData!['status'] == 'In-service'
                                  ? Colors.green.withValues(alpha:0.1)
                                  : Colors.orange.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _busData!['status'],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color:
                                _busData!['status'] == 'In-service'
                                    ? Colors.green
                                    : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Capacity",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        "$currentLoad / $capacity Students",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: loadPercent,
                    backgroundColor: Colors.grey[200],
                    color: loadPercent > 0.9 ? Colors.red : Colors.blue,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text(
              "Passenger List",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),

            // 2. PASSENGER LIST
            passengers.isEmpty
                ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    "No students assigned yet.",
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                )
                : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: passengers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = passengers[index];
                    final hasLocation =
                        p['location'] != null &&
                        p['location'].toString().isNotEmpty;

                    return Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Text(
                            p['name'][0],
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                        title: Text(
                          p['name'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),

                        // --- UPDATED SUBTITLE LOGIC ---
                        subtitle: Text(
                          hasLocation
                              ? p['location']
                              : "No Stop Selected (Manual Assign)",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color:
                                hasLocation ? Colors.grey : Colors.orange[800],
                            fontStyle:
                                hasLocation
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                          ),
                        ),

                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            // Placeholder for removal
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "To remove, edit student profile.",
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }
}
