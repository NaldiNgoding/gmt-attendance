import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'welcome_page.dart';
import 'attendance_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter(); // ← tambah
  await Hive.openBox('attendance_pending'); // ← tambah

  final prefs = await SharedPreferences.getInstance();
  final empid = prefs.getString('empid') ?? '';

  runApp(GmtApp(isLoggedIn: empid.isNotEmpty));
}

class GmtApp extends StatelessWidget {
  final bool isLoggedIn;

  const GmtApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GMT ATTENDANCE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        fontFamily: 'Inter',
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E88E5),
          secondary: Color(0xFF0D47A1),
          surface: Color(0xFFF0F4F8),
        ),
      ),
      home: isLoggedIn ? const HomePage() : const WelcomePage(),
    );
  }
}
