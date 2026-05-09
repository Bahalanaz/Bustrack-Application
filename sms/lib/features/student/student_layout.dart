import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
// 1. IMPORT THE RESPONSIVE WIDGET
import '../../../shared/widgets/responsive_center.dart'; 

// Screen Imports
import 'home/student_home_screen.dart';
import 'history/attendance_history_screen.dart';
import 'schedule/schedule_screen.dart';
import 'profile/profile_screen.dart';

class StudentLayout extends StatefulWidget {
  const StudentLayout({super.key});

  @override
  State<StudentLayout> createState() => _StudentLayoutState();
}

class _StudentLayoutState extends State<StudentLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const StudentHomeScreen(), 
    const AttendanceHistoryScreen(), 
    const ScheduleScreen(), 
    const ProfileScreen(), 
  ];

  final List<String> _titles = ["Home", "History", "Bus Schedule", "Profile"];

  @override
  Widget build(BuildContext context) {
    // --- DYNAMIC THEME COLORS ---
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final navBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark ? Colors.grey[800] : Colors.grey[200];
    final shadowColor = isDark ? Colors.black.withValues(alpha:0.5) : Colors.black.withValues(alpha:0.05);

    final bool showAppBar = _selectedIndex == 2;

    return Scaffold(
      backgroundColor: bgColor,

      appBar: showAppBar
          ? AppBar(
              backgroundColor: navBarColor, 
              elevation: 0,
              centerTitle: true,
              title: Text(
                _titles[_selectedIndex],
                style: GoogleFonts.poppins(
                  color: textColor, 
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: dividerColor, height: 1), 
              ),
            )
          : null, 

      // 2. WRAP THE BODY WITH RESPONSIVE CENTER
      // This forces the content to stay centered (max 600px wide) on Chrome
      body: ResponsiveCenter(
        child: IndexedStack(index: _selectedIndex, children: _screens),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBarColor, 
          boxShadow: [
            BoxShadow(
              color: shadowColor, 
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: AppColors.primary.withValues(alpha:0.1),
            labelTextStyle: WidgetStateProperty.all(
              GoogleFonts.poppins(
                fontSize: 12, 
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.black87, 
              ),
            ),
            iconTheme: WidgetStateProperty.all(
               IconThemeData(color: isDark ? Colors.grey[400] : Colors.black54),
            ),
          ),
          child: NavigationBar(
            height: 70,
            elevation: 0,
            backgroundColor: navBarColor, 
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.primary),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded, color: AppColors.primary),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                label: 'Schedule',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}