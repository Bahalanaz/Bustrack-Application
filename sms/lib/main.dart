import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'data/mock_data_store.dart';
import 'features/splash/splash_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MockDataStore()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const BusManagementApp(),
    ),
  );
}

class BusManagementApp extends StatelessWidget {
  const BusManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'University Bus System',
      debugShowCheckedModeBanner: false,

      // 1. LIGHT THEME (With Poppins)
      theme: AppTheme.lightTheme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(AppTheme.lightTheme.textTheme),
      ),

      // 2. DARK THEME (With Poppins)
      // We use the 'AppTheme.darkTheme' we just created, and ensure Poppins is applied
      darkTheme: AppTheme.darkTheme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(AppTheme.darkTheme.textTheme),
      ),

      // 3. THEME MODE (Controlled by Settings)
      themeMode: themeProvider.themeMode,

      home: const SplashScreen(),
    );
  }
}