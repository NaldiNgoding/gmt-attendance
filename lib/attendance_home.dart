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
import 'att_announcement.dart';
import 'package:flutter/cupertino.dart';

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
  int _selectedNavIndex = 0;
  Map<String, dynamic>? attendanceData;
  Map<String, dynamic>? shiftData;

  static const Color kPrimary = Color(0xFF1E88E5);
  static const Color kSecondary = Color(0xFF0D47A1);
  static const Color kSuccess = Color(0xFF4CAF50);
  static const Color kWarning = Color(0xFFFF9800);
  // ignore: unused_field
  static const Color kTextBlue = Color(0xFF1A365D);
  static const Color kBackground = Color(0xFFF6F7FA);
  static const Color kDarkText = Color(0xFF172033);
  static const Color kMutedText = Color(0xFF7A8496);
  static const Color kBorder = Color(0xFFE7EAF0);

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
      "checkin": DateFormat('HH:mm').format(now),
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
      "checkout": DateFormat('HH:mm').format(now),
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
          key: ValueKey('attendance-log-$empId'),
          employeeId: empId,
          employeeName: userName,
        ),
      ),
    );
  }

  void _selectBottomNav(int index) {
    if (index == 1 && empId.isEmpty) {
      return;
    }
    setState(() {
      _selectedNavIndex = index;
    });
  }

  String _getGreeting() {
    int hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      extendBody: true,
      body: IndexedStack(
        index: _selectedNavIndex,
        children: [
          _buildHomeContent(),
          empId.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : AttendanceLogScreen(
                  key: ValueKey('attendance-log-$empId'),
                  employeeId: empId,
                  employeeName: userName,
                ),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ==========================================================
        // HEADER + SHIFT CARD
        // ==========================================================
        SliverToBoxAdapter(
          child: SizedBox(
            height: 430,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 245,
                  child: _buildHeader(),
                ),
                Positioned(
                  top: 165,
                  left: 20,
                  right: 20,
                  child: _buildShiftCard(),
                ),
              ],
            ),
          ),
        ),

        // ==========================================================
        // CORE PILLARS
        // ==========================================================
        SliverToBoxAdapter(
          child: _buildCorePillars(),
        ),
        // ==========================================================
        // MAIN MENU
        // ==========================================================
        SliverToBoxAdapter(
          child: _buildMenuSection(),
        ),
        // ==========================================================
        // ANNOUNCEMENT
        // ==========================================================
        SliverToBoxAdapter(
          child: const AnnouncementSection(),
        ),

        // Bottom spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: 110),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 18,
        20,
        30,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kPrimary,
            kSecondary,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userName.isNotEmpty ? userName : 'Karyawan',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                DateFormat(
                  'EEEE, d MMMM yyyy',
                ).format(_currentTime),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _openProfile,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: kSecondary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: kBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: kSecondary.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: kPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'Shift Hari Ini',
                      style: TextStyle(
                        color: kDarkText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (shiftData?['shiftname'] != null &&
                  shiftData!['shiftname'].toString().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shiftData!['shiftname'].toString(),
                    style: const TextStyle(
                      color: kSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // ----------------------------------------------------------
          // TIME
          // ----------------------------------------------------------
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jam Kerja',
                      style: TextStyle(
                        color: kMutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      shiftData?['schedulein'] ?? '-',
                      style: const TextStyle(
                        color: kDarkText,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: kBorder,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sampai',
                        style: TextStyle(
                          color: kMutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        shiftData?['scheduleout'] ?? '-',
                        style: const TextStyle(
                          color: kDarkText,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ----------------------------------------------------------
          // ACTION BUTTONS
          // ----------------------------------------------------------
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
                        builder: (context) => const CheckLocationPage(
                          isCheckIn: true,
                        ),
                      ),
                    );

                    if (result == null || result['canProceed'] != true) {
                      return;
                    }

                    final File? photo = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CameraPage(
                          isCheckIn: true,
                          employeeId: result['employeeId'],
                          employeeName: result['employeeName'],
                          attendanceId: result['attendanceId'],
                          locationData: result['locationData'],
                          currentPosition: result['currentPosition'],
                          canCheckInOut: result['canCheckInOut'],
                        ),
                      ),
                    );
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      final base64Image = base64Encode(bytes);
                      await _clockIn(base64Image);
                      _showSuccessDialog(
                        "Check In Berhasil",
                        "Anda berhasil melakukan Check In.",
                      );
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
                        builder: (context) => const CheckLocationPage(
                          isCheckIn: false,
                        ),
                      ),
                    );

                    if (result == null || result['canProceed'] != true) {
                      return;
                    }

                    final File? photo = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CameraPage(
                          isCheckIn: false,
                          employeeId: result['employeeId'],
                          employeeName: result['employeeName'],
                          attendanceId: result['attendanceId'],
                          locationData: result['locationData'],
                          currentPosition: result['currentPosition'],
                          canCheckInOut: result['canCheckInOut'],
                        ),
                      ),
                    );

                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      final base64Image = base64Encode(bytes);
                      await _clockOut(base64Image);
                      _showSuccessDialog(
                        "Check Out Berhasil",
                        "Anda berhasil melakukan Check Out.",
                      );
                      await _loadHomeData();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.08),
          foregroundColor: color,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: color.withOpacity(0.12),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorePillars() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20,
      ),
      child: Center(
        child: Image.asset(
          'assets/images/core.png',
          width: MediaQuery.of(context).size.width * 0.62,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20,
      ),
      padding: const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        30,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: kBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Main Menu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kDarkText,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMenuItem(
                      icon: CupertinoIcons.clock_fill,
                      title: 'Riwayat',
                      color: kPrimary,
                      onTap: _openAttendanceLog,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _buildMenuItem(
                      icon: CupertinoIcons.calendar_badge_minus,
                      title: 'Time Off',
                      color: Colors.teal,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _buildMenuItem(
                      icon: CupertinoIcons.timer_fill,
                      title: 'Lembur',
                      color: kWarning,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OvertimeSubmissionPage(
                              empid: empId,
                              nama: userName,
                              nik: userId,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildMenuItem(
                      icon: CupertinoIcons.doc_checkmark_fill,
                      title: 'Approval',
                      color: kSuccess,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _buildMenuItem(
                      icon: CupertinoIcons.person_solid,
                      title: 'Profil',
                      color: kSecondary,
                      onTap: _openProfile,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _buildMenuItem(
                      icon: CupertinoIcons.question_circle_fill,
                      title: 'Bantuan',
                      color: Colors.purple,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ],
          )
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
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.18),
                  color.withOpacity(0.06),
                ],
              ),
              border: Border.all(
                color: color.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 27,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kDarkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          18,
          0,
          18,
          12,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: kBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _bottomNavItem(
                icon: CupertinoIcons.house_fill,
                label: 'Beranda',
                isSelected: _selectedNavIndex == 0,
                onTap: () => _selectBottomNav(0),
              ),
            ),
            Expanded(
              child: _bottomNavItem(
                icon: CupertinoIcons.clock_fill,
                label: 'Riwayat',
                isSelected: _selectedNavIndex == 1,
                onTap: () => _selectBottomNav(1),
              ),
            ),
            Expanded(
              child: _bottomNavItem(
                icon: CupertinoIcons.person_solid,
                label: 'Profil',
                isSelected: _selectedNavIndex == 2,
                onTap: () => _selectBottomNav(2),
              ),
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
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 6,
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? kPrimary : Colors.grey.shade400,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? kPrimary : Colors.grey.shade400,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
