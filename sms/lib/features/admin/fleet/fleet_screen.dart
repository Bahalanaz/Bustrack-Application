import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/attendance_service.dart';
import 'bus_details_screen.dart'; // <--- 1. Import the new screen

class FleetScreen extends StatefulWidget {
  const FleetScreen({super.key});

  @override
  State<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends State<FleetScreen>
    with SingleTickerProviderStateMixin {
  final AttendanceService _service = AttendanceService();
  late TabController _tabController;

  // Real Data State
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAllData();
  }

  // 1. Fetch Real Data
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      final busData = await _service.getBuses();
      final driverData = await _service.getDrivers();

      setState(() {
        _buses = busData;
        _drivers = driverData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // --- ACTIONS: ASSIGN DRIVER ---
  void _showAssignDriverDialog(int busId, String currentDriver) {
    final List<String> driverNames =
        _drivers.map((d) => d['name'].toString()).toList();

    if (driverNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No drivers available. Add a driver first."),
        ),
      );
      return;
    }

    String? selectedDriver;
    if (driverNames.contains(currentDriver)) {
      selectedDriver = currentDriver;
    } else {
      selectedDriver = driverNames.first;
    }

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  "Assign Driver",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select a driver from the list:",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedDriver,
                          items:
                              driverNames.map((name) {
                                return DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                );
                              }).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedDriver = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedDriver == null) return;
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      try {
                        await _service.assignDriverToBus(
                          busId,
                          selectedDriver!,
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text("Assigned $selectedDriver to bus"),
                          ),
                        );
                        _fetchAllData();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text("Error: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text("Save"),
                  ),
                ],
              );
            },
          ),
    );
  }

  // --- ACTIONS: ADD BUS ---
  void _showAddBusDialog() {
    final plateController = TextEditingController();
    final capacityController = TextEditingController(text: "30");
    String status = "Active";

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              "Add New Bus",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Model",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Toyota Coaster",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: plateController,
                  decoration: const InputDecoration(
                    labelText: "Plate Number (e.g. DXB 1234)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Capacity",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: "Initial Status",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "Active",
                      child: Text("Active (In-Service)"),
                    ),
                    DropdownMenuItem(
                      value: "Maintenance",
                      child: Text("Maintenance"),
                    ),
                  ],
                  onChanged: (val) => status = val!,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (plateController.text.isEmpty) return;
                  final messenger = ScaffoldMessenger.of(ctx);
                  Navigator.pop(ctx);
                  final dbStatus =
                      status == "Active" ? "In-service" : "Maintenance";
                  try {
                    await _service.addBus(
                      plateController.text,
                      int.tryParse(capacityController.text) ?? 30,
                      dbStatus,
                    );
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Bus Added Successfully")),
                    );
                    _fetchAllData();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text("Add Bus"),
              ),
            ],
          ),
    );
  }

  // --- ACTIONS: ADD DRIVER ---
  void _showAddDriverDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final licenseController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              "Add New Driver",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: licenseController,
                  decoration: const InputDecoration(
                    labelText: "License Expiry (e.g. 2026)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) return;
                  final messenger = ScaffoldMessenger.of(ctx);
                  Navigator.pop(ctx);
                  try {
                    await _service.addDriver(
                      nameController.text,
                      phoneController.text,
                      licenseController.text,
                    );
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text("Driver Added Successfully"),
                      ),
                    );
                    _fetchAllData();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text("Error: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text("Add Driver"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      children: [
        // 1. CUSTOM TAB BAR
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            tabs: const [Tab(text: "Bus Registry"), Tab(text: "Drivers")],
          ),
        ),

        // 2. TAB CONTENT
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Text("Error: $_errorMessage"))
                  : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBusTab(isDark, cardColor, textColor),
                      _buildDriverTab(isDark, cardColor, textColor),
                    ],
                  ),
        ),
      ],
    );
  }

  // --- TAB 1: BUS REGISTRY UI ---
  Widget _buildBusTab(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        // HEADER ROW (Always Visible)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Buses: ${_buses.length}",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              ElevatedButton.icon(
                onPressed: _showAddBusDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add New Bus"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),

        // BUS LIST
        Expanded(
          child:
              _buses.isEmpty
                  ? Center(
                    child: Text(
                      "No buses found. Add one!",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _buses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final bus = _buses[index];
                      final isActive =
                          bus['status'] == "In-service" ||
                          bus['status'] == "Active";
                      final driverName = bus['driver'];

                      return InkWell(
                        onTap: () {
                          // 2. NAVIGATE TO DETAILS
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => BusDetailsScreen(
                                    busId: bus['db_id'],
                                    busName: "Bus ${bus['id']}",
                                  ),
                            ),
                          ).then((_) => _fetchAllData()); // Refresh on return
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isDark
                                      ? Colors.white10
                                      : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha:0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.directions_bus_filled,
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
                                      "Bus ${bus['id']}",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      "${bus['model']}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      bus['plate'],
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      // Prevent tap propagation so we can edit driver without opening details
                                      onTap:
                                          () => _showAssignDriverDialog(
                                            bus['db_id'],
                                            driverName,
                                          ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 14,
                                            color:
                                                driverName == "Unassigned"
                                                    ? Colors.red
                                                    : Colors.blue,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            driverName,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  driverName == "Unassigned"
                                                      ? Colors.red
                                                      : Colors.blue,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.edit,
                                            size: 12,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isActive
                                              ? Colors.green.withValues(alpha:0.1)
                                              : Colors.orange.withValues(alpha:0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      bus['status'],
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isActive
                                                ? Colors.green
                                                : Colors.orange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Cap: ${bus['capacity']}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  // --- TAB 2: DRIVER LIST UI ---
  Widget _buildDriverTab(bool isDark, Color cardColor, Color textColor) {
    return Column(
      children: [
        // HEADER ROW (Always Visible)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Drivers: ${_drivers.length}",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              ElevatedButton.icon(
                onPressed: _showAddDriverDialog,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text("Add New Driver"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),

        // LIST
        Expanded(
          child:
              _drivers.isEmpty
                  ? Center(
                    child: Text(
                      "No drivers found. Add one!",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _drivers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final driver = _drivers[index];
                      final onShift = driver['status'] == "On Shift";

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDark ? Colors.white10 : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              radius: 22,
                              child: Text(
                                driver['name'][0],
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver['name'],
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    driver['phone'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    driver['license'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    onShift
                                        ? Colors.green.withValues(alpha:0.1)
                                        : Colors.grey.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                driver['status'],
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                  color: onShift ? Colors.green : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
