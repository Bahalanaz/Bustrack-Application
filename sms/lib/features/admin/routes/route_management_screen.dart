import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/attendance_service.dart';

class RouteManagementScreen extends StatefulWidget {
  const RouteManagementScreen({super.key});

  @override
  State<RouteManagementScreen> createState() => _RouteManagementScreenState();
}

class _RouteManagementScreenState extends State<RouteManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AttendanceService _service = AttendanceService();

  // Data State
  List<dynamic> _routes = [];
  List<dynamic> _stops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Updates FAB visibility on swipe
    });
    _fetchData();
  }

  // 1. FETCH DATA FROM BACKEND
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final routesData = await _service.getActiveRoutes();
      final stopsData = await _service.getAllStops();

      if (mounted) {
        setState(() {
          _routes = routesData;
          _stops = stopsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && context.mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading data: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 2. SHOW "ADD STOP" DIALOG
  void _showAddStopDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AddStopDialog(
            service: _service,
            onSuccess: () {
              _fetchData(); // Refresh list after adding
            },
          ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final isStopsTab = _tabController.index == 1;

    return Column(
      children: [
        // 1. TOOLBAR SECTION
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
          ),
          child: Row(
            children: [
              // TABS
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: "Active Routes"),
                      Tab(text: "Bus Stops"),
                    ],
                  ),
                ),
              ),

              // BUTTON (Only shows if we are on the 'Bus Stops' tab)
              if (isStopsTab) ...[
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showAddStopDialog, // <--- CALLS DIALOG
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                  label: Text(
                    "Add Stop",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. TAB CONTENT
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveRoutesList(isDark, cardColor, textColor),
                      _buildStopsList(isDark, cardColor, textColor),
                    ],
                  ),
        ),
      ],
    );
  }

  // --- TAB 1: ACTIVE ROUTES ---
  Widget _buildActiveRoutesList(bool isDark, Color cardColor, Color textColor) {
    if (_routes.isEmpty) {
      return Center(
        child: Text(
          "No active routes found.\nAdd a Bus first!",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _routes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final route = _routes[index];
          return _buildRouteCard(
            title: route['title'] ?? "Unknown Route",
            driver: route['driver'] ?? "No Driver",
            bus: route['bus_number'] ?? "N/A",
            stops: route['stops_count'] ?? 0,
            students: route['student_count'] ?? 0,
            capacity: route['capacity'] ?? 30,
            status: route['status'] ?? "Unknown",
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
          );
        },
      ),
    );
  }

  Widget _buildRouteCard({
    required String title,
    required String driver,
    required String bus,
    required int stops,
    required int students,
    required int capacity,
    required String status,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
  }) {
    final isLive = status == "In-service";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.alt_route_rounded,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "$stops Stops Assigned",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isLive
                          ? Colors.green.withValues(alpha:0.1)
                          : Colors.orange.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: isLive ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 32, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn(
                "Driver",
                driver,
                Icons.person_outline,
                textColor,
              ),
              _buildInfoColumn(
                "Bus",
                bus,
                Icons.directions_bus_outlined,
                textColor,
              ),
              _buildInfoColumn(
                "Load",
                "$students/$capacity",
                Icons.groups_outlined,
                textColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(
    String label,
    String value,
    IconData icon,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // --- TAB 2: BUS STOPS ---
  Widget _buildStopsList(bool isDark, Color cardColor, Color textColor) {
    if (_stops.isEmpty) {
      return Center(
        child: Text(
          "No bus stops added yet.",
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _stops.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final stop = _stops[index];
          return Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: Colors.red.withValues(alpha:0.1),
                radius: 20,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              title: Text(
                stop['name'] ?? "Unknown",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                "${stop['area']} • Bus: ${stop['assigned_bus']}",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              trailing: Text(
                stop['pickup_time'] ?? "07:00 AM",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
//                            ADD STOP DIALOG WIDGET
// =============================================================================

class AddStopDialog extends StatefulWidget {
  final AttendanceService service;
  final VoidCallback onSuccess;

  const AddStopDialog({
    super.key,
    required this.service,
    required this.onSuccess,
  });

  @override
  State<AddStopDialog> createState() => _AddStopDialogState();
}

class _AddStopDialogState extends State<AddStopDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _timeController = TextEditingController(text: "07:00 AM");

  List<dynamic> _buses = [];
  int? _selectedBusId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBuses();
  }

  Future<void> _fetchBuses() async {
    try {
      final list = await widget.service.getBusDropdownList();
      setState(() {
        _buses = list;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedBusId == null) {
      if (_selectedBusId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Please select a bus")));
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.service.addBusStop(
        _nameController.text.trim(),
        _areaController.text.trim(),
        _selectedBusId!,
        _timeController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context); // Close dialog
        widget.onSuccess(); // Refresh parent list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Stop added successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        "Add Bus Stop",
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Stop Name (e.g. Metro Exit)",
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: "Area (e.g. Bur Dubai)",
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _timeController,
                decoration: const InputDecoration(
                  labelText: "Pickup Time (e.g. 07:30 AM)",
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selectedBusId,
                decoration: const InputDecoration(
                  labelText: "Assign to Bus",
                  border: OutlineInputBorder(),
                ),
                items:
                    _buses.map<DropdownMenuItem<int>>((bus) {
                      return DropdownMenuItem<int>(
                        value: bus['id'],
                        child: Text(bus['plate']),
                      );
                    }).toList(),
                onChanged: (val) => setState(() => _selectedBusId = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text("Add Stop"),
        ),
      ],
    );
  }
}
