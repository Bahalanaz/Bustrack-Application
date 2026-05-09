import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/attendance_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final AttendanceService _service = AttendanceService();
  late Future<Map<String, dynamic>> _profileFuture;

  int _selectedDayIndex = 0;
  int _selectedRouteMode = 0; // 0 = Morning, 1 = Return

  // Generate next 14 days
  final List<DateTime> _weekDays = List.generate(
    14,
    (index) => DateTime.now().add(Duration(days: index)),
  );

  @override
  void initState() {
    super.initState();
    _profileFuture = _service.getStudentProfile();
  }

  Future<void> _launchMap(String locationName) async {
    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(locationName)}",
    );

    try {
      if (!await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Could not launch maps');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Could not open maps: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme Variables
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryColor = AppColors.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER (Month & Date Selector)
            _buildHeaderSection(isDark, textColor, subTextColor, primaryColor),

            const SizedBox(height: 20),

            // 2. SEGMENTED CONTROL (Toggle)
            _buildSegmentedControl(isDark, cardColor, textColor, subTextColor),

            const SizedBox(height: 24),

            // 3. TIMELINE CONTENT (Future Builder)
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  // A. Loading
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // B. Error
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 40,
                            color: subTextColor,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Could not load schedule",
                            style: GoogleFonts.poppins(color: subTextColor),
                          ),
                          TextButton(
                            onPressed:
                                () => setState(() {
                                  _profileFuture = _service.getStudentProfile();
                                }),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    );
                  }

                  // C. Data Loaded
                  final data = snapshot.data!;
                  final student = data['student'];

                  // FIX: Added '?? []' to handle null safety if backend doesn't send schedule
                  final List<dynamic> weeklySchedule =
                      data['weekly_schedule'] ?? [];

                  // Get selected date details
                  final selectedDate = _weekDays[_selectedDayIndex];
                  final dayName = DateFormat(
                    'EEEE',
                  ).format(selectedDate); // e.g., "Monday"

                  // Find schedule for this day
                  // FIX: Safe check if weeklySchedule is empty
                  final daySchedule =
                      weeklySchedule.isEmpty
                          ? {'active': false}
                          : weeklySchedule.firstWhere(
                            (day) => day['day'] == dayName,
                            orElse: () => {'active': false},
                          );

                  final bool isActive = daySchedule['active'] ?? false;
                  final String busId = student['Assigned_Bus'] ?? "N/A";

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child:
                        isActive
                            ? (_selectedRouteMode == 0
                                ? _buildMorningRoute(
                                  busId,
                                  isDark,
                                  cardColor,
                                  textColor,
                                  subTextColor,
                                )
                                : _buildReturnRoute(
                                  busId,
                                  isDark,
                                  cardColor,
                                  textColor,
                                  subTextColor,
                                ))
                            : _buildNoScheduleView(
                              dayName,
                              isDark,
                              subTextColor,
                            ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- VIEW HELPERS ---

  Widget _buildNoScheduleView(String dayName, bool isDark, Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 40,
              color: subTextColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No Bus on $dayName",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Enjoy your day off!",
            style: GoogleFonts.poppins(fontSize: 14, color: subTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMorningRoute(
    String busId,
    bool isDark,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    return _buildTimelineCard(
      title: "Morning Route",
      busId: busId,
      driver: "Assigned Driver",
      status: "Scheduled",
      stops: [
        TimelineStep("06:30 AM", "Standard Pickup Point", "Pickup"),
        TimelineStep("07:15 AM", "Highway E311 Stop", "Transit"),
        TimelineStep(
          "08:15 AM",
          "University Campus",
          "Drop-off",
          isDestination: true,
        ),
      ],
      isDark: isDark,
      cardColor: cardColor,
      textColor: textColor,
      subTextColor: subTextColor,
    );
  }

  Widget _buildReturnRoute(
    String busId,
    bool isDark,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    return _buildTimelineCard(
      title: "Return Route",
      busId: busId,
      driver: "Assigned Driver",
      status: "Scheduled",
      stops: [
        TimelineStep("04:00 PM", "University Campus", "Pickup"),
        TimelineStep("05:30 PM", "Highway E311 Stop", "Drop-off"),
        TimelineStep(
          "06:00 PM",
          "Standard Drop-off Point",
          "Final Stop",
          isDestination: true,
        ),
      ],
      isDark: isDark,
      cardColor: cardColor,
      textColor: textColor,
      subTextColor: subTextColor,
    );
  }

  // --- WIDGET HELPERS (Unchanged visual logic) ---

  Widget _buildHeaderSection(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color primary,
  ) {
    final selectedDate = _weekDays[_selectedDayIndex];
    final monthYear = DateFormat('MMMM yyyy').format(selectedDate);

    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Section
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  monthYear,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Calendar Strip
          SizedBox(
            height: 70,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _weekDays.length,
              separatorBuilder: (_, __) => const SizedBox(width: 20),
              itemBuilder: (context, index) {
                final date = _weekDays[index];
                final isSelected = index == _selectedDayIndex;
                final dayName = DateFormat('EEE').format(date).toUpperCase();
                final dayNumber = DateFormat('d').format(date);

                return GestureDetector(
                  onTap: () => setState(() => _selectedDayIndex = index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayName,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? primary : subTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 36,
                        width: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? primary : Colors.transparent,
                          shape: BoxShape.circle,
                          border:
                              isSelected
                                  ? null
                                  : Border.all(
                                    color:
                                        isDark
                                            ? Colors.grey[700]!
                                            : Colors.grey[300]!,
                                  ),
                        ),
                        child: Text(
                          dayNumber,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : textColor,
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
      ),
    );
  }

  Widget _buildSegmentedControl(
    bool isDark,
    Color cardColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSegmentOption(
            "Morning Trip",
            0,
            isDark,
            textColor,
            subTextColor,
          ),
          _buildSegmentOption(
            "Return Trip",
            1,
            isDark,
            textColor,
            subTextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentOption(
    String label,
    int index,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final isSelected = _selectedRouteMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRouteMode = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                isSelected
                    ? (isDark ? const Color(0xFF424242) : Colors.white)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.05),
                        blurRadius: 4,
                      ),
                    ]
                    : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? textColor : subTextColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineCard({
    required String title,
    required String busId,
    required String driver,
    required String status,
    required List<TimelineStep> stops,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Route Info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$status • Bus $busId",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Driver
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.withValues(alpha:0.3)),
              ),
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Timeline Construction
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stops.length,
          itemBuilder: (context, index) {
            final stop = stops[index];
            final isLast = index == stops.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time
                  SizedBox(
                    width: 60,
                    child: Text(
                      stop.time,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),

                  // Vertical Line
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color:
                              stop.isDestination
                                  ? AppColors.primary
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                stop.isDestination
                                    ? AppColors.primary
                                    : Colors.grey.withValues(alpha:0.5),
                            width: 2,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isDark ? Colors.grey[800] : Colors.grey[300],
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Details
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.location,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stop.description,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Map Button
                  IconButton(
                    onPressed: () => _launchMap(stop.location),
                    icon: Icon(
                      Icons.map_outlined,
                      size: 18,
                      color: subTextColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 30),

        // Contact Driver Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text("Contact Driver"),
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class TimelineStep {
  final String time;
  final String location;
  final String description;
  final bool isDestination;

  TimelineStep(
    this.time,
    this.location,
    this.description, {
    this.isDestination = false,
  });
}
