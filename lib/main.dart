import 'package:flutter/material.dart';
import 'welcome_page.dart';
import 'package:camera/camera.dart';

// ==== Tambahkan ini (global variable kamera) ====
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // WAJIB

  // Load semua kamera dari device
  cameras = await availableCameras(); // WAJIB

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GMT Attendance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      home: const WelcomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
