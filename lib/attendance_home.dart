import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'camera_page.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'checklocation.dart';
import 'attendance_log_screen.dart';
import 'profile_page.dart';
import 'lembur.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color kPrimary = Color(0xFF1E88E5);
  static const Color kSecondary = Color(0xFF0D47A1);
  static const Color kSuccess = Color(0xFF4CAF50);
  static const Color kWarning = Color(0xFFFF9800);
  static const Color kError = Color(0xFFF44336);
  static const Color kSurface = Color(0xFFF0F4F8); // Soft blue surface

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kSurface,
        fontFamily: 'Inter',
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: kPrimary,
          secondary: kSecondary,
          surface: kSurface,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _currentTime = DateTime.now();
  String userName = "";
  String userId = "";
  String empId = "";
  String userAccount = "";
  Map<String, dynamic>? attendanceData;
  Map<String, dynamic>? shiftData;

  // Blue Luxury Colors
  static const Color kPrimary = Color(0xFF1E88E5);
  static const Color kSecondary = Color(0xFF0D47A1);
  static const Color kSuccess = Color(0xFF4CAF50);
  static const Color kWarning = Color(0xFFFF9800);
  static const Color kTextBlue = Color(0xFF1A365D);

  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) {
      _loadHomeData(); // Panggil setelah user data selesai
    });
    _updateTime();
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateTime.now();
    });
    Future.delayed(const Duration(minutes: 1), _updateTime);
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      userName = prefs.getString('empname') ?? "Karyawan";
      userId = prefs.getString('userid') ?? "";
      // Ambil empId dari SharedPreferences, sudah seharusnya 1984
      empId = prefs.getString('empid') ?? "";
      userAccount = prefs.getString('username') ?? "";
    });
  }

  Future<void> _loadHomeData() async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final url =
          "http://localhost:8000/api/new_gethomedata?employeeid=$empId&date=$today";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['success'] == true && json['data']['employee'] != null) {
          setState(() {
            attendanceData = json['data']['attendance'];
            shiftData = json['data']['shift'];
          });
        } else {}
      } else {}
    } catch (e) {}
  }

  Future<void> _clockIn(String base64image) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String empId = prefs.getString('empid') ?? "";
    String empName = prefs.getString('empname') ?? "";
    DateTime now = DateTime.now();
    final url = Uri.parse("http://localhost:8000/api/new_clockin");
    final body = {
      "id": "",
      "employeeid": empId,
      "date": DateFormat('yyyy-MM-dd').format(now),
      "checkin": DateFormat('HH:mm:ss').format(now),
      "createdby": empName,
      "createddate": DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
      "status": "Present",
      "ext": "jpg",
      "data": base64image,
      "locationsettingname": "Office",
      "locationaddress": "Jl. ABC",
      "locationcoordinate": "-6.2000,106.8166",
      "description": "Clock In",
      "requesttime": DateFormat('yyyy-MM-dd HH:mm:ss').format(now)
    };
    await http.post(url,
        headers: {"Content-Type": "application/json"}, body: json.encode(body));
  }

  Future<void> _clockOut(String base64image) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String empId = prefs.getString('empid') ?? "";
    String empName = prefs.getString('empname') ?? "";
    DateTime now = DateTime.now();
    final url = Uri.parse("http://localhost:8000/api/new_clockout");
    final body = {
      "id": "",
      "employeeid": empId,
      "date": DateFormat('yyyy-MM-dd').format(now),
      "checkout": DateFormat('HH:mm:ss').format(now),
      "createdby": empName,
      "createddate": DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
      "status": "Present",
      "ext": "jpg",
      "data": base64image,
      "locationsettingname": "Office",
      "locationaddress": "Jl. ABC",
      "locationcoordinate": "-6.2000,106.8166",
      "description": "Clock Out",
      "requesttime": DateFormat('yyyy-MM-dd HH:mm:ss').format(now)
    };
    await http.post(url,
        headers: {"Content-Type": "application/json"}, body: json.encode(body));
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kSuccess.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: kSuccess, size: 48),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("OK",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }

  void _openAttendanceLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceLogScreen(
          employeeId: empId,
          employeeName: userName,
        ),
      ),
    );
  }

  String _getGreeting() {
    int hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image - tengah dengan ukuran proporsional
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'assets/images/GMT3.png',
                  width: screenSize.width * 0.45,
                  height: screenSize.width * 0.45,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header dengan greeting
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: kTextBlue.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userName,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: kTextBlue,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _openProfile,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [kPrimary, kSecondary],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kPrimary.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(_currentTime),
                          style: TextStyle(
                            fontSize: 13,
                            color: kTextBlue.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Shift Card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kPrimary, kSecondary],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -20,
                          right: -20,
                          child: Icon(Icons.work_outline,
                              size: 120, color: Colors.white.withOpacity(0.08)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Shift Hari Ini',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (shiftData?['shiftname'] != null &&
                                        shiftData!['shiftname']
                                            .toString()
                                            .isNotEmpty) ...[
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.25),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          shiftData!['shiftname'].toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Jam Kerja',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          shiftData?['schedulein'] ??
                                              '-', // BENAR
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Sampai',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          shiftData?['scheduleout'] ??
                                              '-', // BENAR
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.login_rounded,
                                      label: 'Clock In',
                                      color: kSuccess,
                                      onTap: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const CheckLocationPage(
                                                    isCheckIn: true),
                                          ),
                                        );
                                        if (result == null ||
                                            result['canProceed'] != true)
                                          return;

                                        final File? photo =
                                            await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CameraPage(
                                              isCheckIn: true,
                                              employeeId: result['employeeId'],
                                              employeeName:
                                                  result['employeeName'],
                                              attendanceId:
                                                  result['attendanceId'],
                                              locationData:
                                                  result['locationData'],
                                              currentPosition:
                                                  result['currentPosition'],
                                              canCheckInOut:
                                                  result['canCheckInOut'],
                                            ),
                                          ),
                                        );

                                        if (photo != null) {
                                          final bytes =
                                              await photo.readAsBytes();
                                          final base64Image =
                                              base64Encode(bytes);
                                          await _clockIn(base64Image);
                                          _showSuccessDialog(
                                              "Check In Berhasil",
                                              "Anda berhasil melakukan Check In.");
                                          await _loadHomeData();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.logout_rounded,
                                      label: 'Clock Out',
                                      color: kWarning,
                                      onTap: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const CheckLocationPage(
                                                    isCheckIn: false),
                                          ),
                                        );
                                        if (result == null ||
                                            result['canProceed'] != true)
                                          return;

                                        final File? photo =
                                            await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CameraPage(
                                              isCheckIn: false,
                                              employeeId: result['employeeId'],
                                              employeeName:
                                                  result['employeeName'],
                                              attendanceId:
                                                  result['attendanceId'],
                                              locationData:
                                                  result['locationData'],
                                              currentPosition:
                                                  result['currentPosition'],
                                              canCheckInOut:
                                                  result['canCheckInOut'],
                                            ),
                                          ),
                                        );

                                        if (photo != null) {
                                          final bytes =
                                              await photo.readAsBytes();
                                          final base64Image =
                                              base64Encode(bytes);
                                          await _clockOut(base64Image);
                                          _showSuccessDialog(
                                              "Check Out Berhasil",
                                              "Anda berhasil melakukan Check Out.");
                                          await _loadHomeData();
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Gambar Core Pillars
                SliverToBoxAdapter(
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.7,
                          child: Image.asset(
                            'assets/images/core.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Menu Section
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kTextBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.9,
                          children: [
                            _buildMenuItem(
                              icon: Icons.history_rounded,
                              title: 'Riwayat',
                              color: kPrimary,
                              onTap: _openAttendanceLog,
                            ),
                            _buildMenuItem(
                              icon: Icons.beach_access_rounded,
                              title: 'Time Off',
                              color: Colors.teal,
                              onTap: () {},
                            ),
                            _buildMenuItem(
                              icon: Icons.nightlight_round,
                              title: 'Lembur',
                              color: kWarning,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        OvertimeSubmissionPage(
                                      empid: empId,
                                      nama: userName,
                                      nik: userId,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _buildMenuItem(
                              icon: Icons.check_circle_rounded,
                              title: 'Approval',
                              color: kSuccess,
                              onTap: () {},
                            ),
                            _buildMenuItem(
                              icon: Icons.person_rounded,
                              title: 'Profil',
                              color: kSecondary,
                              onTap: _openProfile,
                            ),
                            _buildMenuItem(
                              icon: Icons.help_rounded,
                              title: 'Bantuan',
                              color: Colors.purple,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kTextBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomNavItem(
              icon: Icons.home_rounded,
              label: 'Beranda',
              isSelected: true,
              onTap: () {},
            ),
            _bottomNavItem(
              icon: Icons.history_rounded,
              label: 'Riwayat',
              isSelected: false,
              onTap: _openAttendanceLog,
            ),
            _bottomNavItem(
              icon: Icons.person_rounded,
              label: 'Profil',
              isSelected: false,
              onTap: _openProfile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? kPrimary : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? kPrimary : Colors.grey.shade400,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
