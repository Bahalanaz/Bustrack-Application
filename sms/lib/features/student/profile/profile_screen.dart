import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../../services/attendance_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AttendanceService _service = AttendanceService();
  late Future<Map<String, dynamic>> _profileFuture;

  // Local state for UI toggles
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _profileFuture = _service.getStudentProfile();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Dynamic styling variables
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final settingsIconColor =
        isDark ? Colors.grey[300] : const Color(0xFF555555);
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error State
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Failed to load profile",
                style: TextStyle(color: subTextColor),
              ),
            );
          }

          final data = snapshot.data!;
          final student = data['student'];

          // --- EXTRACT DATA (FIXED) ---
          final String name = student['Student_Name'] ?? "Unknown";
          final String id = student['Student_ID'].toString();
          final String bus = student['Assigned_Bus'] ?? "No Bus";
          final String course = student['Course'] ?? "No Course";
          final String year =
              student['Year_Level'] ?? "Year 1"; // <--- ADDED: EXTRACT YEAR

          return SingleChildScrollView(
            child: Column(
              children: [
                // 1. HEADER SECTION
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      height: 240, // Increased height to fit extra row
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, Color(0xFF1540A0)],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                      child: Column(
                        children: [
                          Center(
                            child: Text(
                              "Student Profile",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // DIGITAL ID CARD
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha:
                                    isDark ? 0.3 : 0.08,
                                  ),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar
                                Container(
                                  width: 75,
                                  height: 75,
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[50],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          isDark
                                              ? Colors.grey[700]!
                                              : Colors.grey.shade200,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      name.isNotEmpty ? name[0] : "?",
                                      style: GoogleFonts.poppins(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Bus: $bus",
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildHeaderInfoRow(
                                        Icons.badge_outlined,
                                        "ID: $id",
                                        subTextColor,
                                      ),
                                      const SizedBox(height: 4),

                                      // --- FIXED: Display Real Course ---
                                      _buildHeaderInfoRow(
                                        Icons.school_outlined,
                                        course,
                                        subTextColor,
                                      ),
                                      const SizedBox(height: 4),

                                      // --- ADDED: Display Real Year ---
                                      _buildHeaderInfoRow(
                                        Icons.calendar_today_outlined,
                                        year,
                                        subTextColor,
                                      ),

                                      const SizedBox(height: 16),

                                      // Status Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha:0.08),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.withValues(alpha:
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              size: 14,
                                              color: Colors.green[700],
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "Account Active",
                                              style: TextStyle(
                                                color: Colors.green[800],
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // 2. SETTINGS GROUP: GENERAL
                _buildSectionTitle("General", subTextColor),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.notifications_none_rounded,
                        title: "Notifications",
                        iconColor: settingsIconColor,
                        textColor: textColor,
                        trailing: Switch(
                          value: _notificationsEnabled,
                          activeThumbColor: AppColors.primary,
                          onChanged:
                              (val) =>
                                  setState(() => _notificationsEnabled = val),
                        ),
                      ),
                      _buildDivider(borderColor),

                      // Dark Mode
                      _buildSettingsTile(
                        icon:
                            themeProvider.isDarkMode
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                        title: "Dark Mode",
                        iconColor: settingsIconColor,
                        textColor: textColor,
                        trailing: Switch(
                          value: themeProvider.isDarkMode,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => themeProvider.toggleTheme(val),
                        ),
                      ),
                      _buildDivider(borderColor),

                      // Language
                      _buildSettingsTile(
                        icon: Icons.language_outlined,
                        title: "Language",
                        iconColor: settingsIconColor,
                        textColor: textColor,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "English",
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: subTextColor,
                            ),
                          ],
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. SETTINGS GROUP: SECURITY & SUPPORT
                _buildSectionTitle("Support & Security", subTextColor),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.security_outlined,
                        title: "Two-Factor Auth",
                        iconColor: settingsIconColor,
                        textColor: textColor,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Setup flow coming soon"),
                            ),
                          );
                        },
                      ),

                      _buildDivider(borderColor),

                      // Help Center
                      _buildSettingsTile(
                        icon: Icons.help_outline_rounded,
                        title: "Help Center",
                        iconColor: settingsIconColor,
                        textColor: textColor,
                        onTap: () {},
                      ),
                      _buildDivider(borderColor),

                      // Privacy Policy
                      _buildSettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        title: "Privacy Policy",
                        iconColor: settingsIconColor,
                        textColor: textColor,
                        onTap: () {},
                      ),
                      _buildDivider(borderColor),

                      // About App
                      _buildSettingsTile(
                        icon: Icons.info_outline_rounded,
                        title: "About App",
                        iconColor: settingsIconColor,
                        textColor: textColor,
                        trailing: Text(
                          "v1.0.2",
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                TextButton.icon(
                  onPressed: () => _handleLogout(context),
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: Colors.red[400],
                  ),
                  label: Text(
                    "Sign Out",
                    style: GoogleFonts.poppins(
                      color: Colors.red[400],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    backgroundColor: Colors.red.withValues(alpha:0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionTitle(String title, Color? color) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfoRow(IconData icon, String text, Color? color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required Color? iconColor,
    required Color textColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing:
          trailing ??
          (onTap != null
              ? Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey[400],
              )
              : null),
      onTap: onTap,
    );
  }

  Widget _buildDivider(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: color),
    );
  }

  void _handleLogout(BuildContext context) async {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text("Log Out"),
            content: const Text("Are you sure you want to sign out?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);

                  // 1. Clear Token
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('auth_token');

                  // 2. Navigate to Login
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
                child: const Text(
                  "Log Out",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}
