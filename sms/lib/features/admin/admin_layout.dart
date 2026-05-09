import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// IMPORTS
import 'dashboard/dashboard_screen.dart'; 
import 'routes/route_management_screen.dart';
import 'students/students_screen.dart';
import 'requests/requests_screen.dart';
import 'fleet/fleet_screen.dart';
import 'fees/fees_screen.dart';
import 'reports/reports_screen.dart';
import 'profile/admin_profile_screen.dart'; 

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;

  final List<String> _titles = [
    "Dashboard",
    "Route Management",
    "Students",
    "Requests",
    "Fleet Management",
    "Fees & Finance", 
    "Reports & Analytics",
    "Settings", // <--- THIS WAS MISSING (Index 7)
  ];

  final List<Widget> _screens = [
    const DashboardScreen(),
    const RouteManagementScreen(),
    const StudentsScreen(),
    const RequestsScreen(),
    const FleetScreen(),
    const FeesScreen(),
    const ReportsScreen(),
    const AdminProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9);
    final headerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      
      // Global drawer for Mobile
      drawer: !isDesktop 
          ? Drawer(width: 260, child: _buildSidebar(isDark)) 
          : null,
      
      body: SafeArea(
        child: Row(
          children: [
            // SIDEBAR (Desktop Only)
            if (isDesktop) 
              SizedBox(width: 260, child: _buildSidebar(isDark)),

            // MAIN CONTENT AREA
            Expanded(
              child: Column(
                children: [
                  // --- TOP HEADER ---
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: headerColor,
                      border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        // Menu Button (Mobile Only)
                        if (!isDesktop)
                          IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                          ),
                        if (!isDesktop) const SizedBox(width: 8),

                        // DYNAMIC TITLE
                        Text(
                          _titles[_selectedIndex], // This caused the error before!
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        
                        const Spacer(),

                        // Global actions
                        IconButton(
                          onPressed: () {}, 
                          icon: const Icon(Icons.notifications_outlined, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // --- SCREEN CONTENT ---
                  Expanded(
                    child: _screens[_selectedIndex],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE SIDEBAR ---
  Widget _buildSidebar(bool isDark) {
    final sidebarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final dividerColor = isDark ? Colors.white10 : Colors.grey[200]!;
    
    return Container(
      decoration: BoxDecoration(
        color: sidebarColor,
        border: Border(right: BorderSide(color: dividerColor)),
      ),
      child: Column(
        children: [
          Container(
            height: 64, 
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.directions_bus, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  "UniTrans",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              children: [
                _buildNavTitle("MAIN"),
                _buildNavItem(0, "Dashboard", Icons.grid_view_rounded),
                const SizedBox(height: 16),
                _buildNavTitle("LOGISTICS"),
                _buildNavItem(1, "Routes", Icons.alt_route_rounded),
                _buildNavItem(2, "Students", Icons.badge_rounded),
                _buildNavItem(3, "Requests", Icons.inbox_rounded),
                const SizedBox(height: 16),
                _buildNavTitle("ASSETS"),
                _buildNavItem(4, "Fleet", Icons.directions_bus_filled_rounded),
                const SizedBox(height: 16),
                _buildNavTitle("BUSINESS"),
                _buildNavItem(5, "Finance", Icons.attach_money_rounded),
                _buildNavItem(6, "Reports", Icons.bar_chart_rounded),
                const SizedBox(height: 16),
                _buildNavTitle("SYSTEM"), 
                _buildNavItem(7, "Settings", Icons.settings_rounded), 
              ],
            ),
          ),
          
          // CLICKABLE USER PROFILE (Links to Settings)
          InkWell(
            onTap: () => _onItemTapped(7), 
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: dividerColor)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(radius: 16, backgroundColor: Colors.grey, child: Icon(Icons.person, size: 20, color: Colors.white)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Admin User", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                      Text("Tap for Settings", style: GoogleFonts.poppins(fontSize: 10, color: Colors.blue)),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNavTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    final primaryColor = const Color(0xFF2563EB);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: () => _onItemTapped(index),
        selected: isSelected,
        selectedTileColor: primaryColor.withValues(alpha:0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(icon, color: isSelected ? primaryColor : Colors.grey[500], size: 22),
        title: Text(title, style: GoogleFonts.poppins(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? primaryColor : Colors.grey[700])),
      ),
    );
  }
}