import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'camera_page.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'checklocation.dart';
import 'attendance_log_screen.dart';
import 'profile_page.dart';
import 'lembur.dart';
import 'att_announcement.dart';
import 'att_approval.dart';
import 'timeoff.dart';
import 'package:flutter/cupertino.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'Offline/offline_att.dart';

// ============================================================
// KONFIGURASI PING (lokal untuk file ini)
// ============================================================
const String kPingUrl = '$kBaseUrl/api/ping';
const String kPublicPingUrl = 'https://www.google.com';

// ============================================================
// ENUM TOP-LEVEL
// ============================================================
enum ConnectionStatus { good, weak, offline }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ==================== STATE ====================
  DateTime _currentTime = DateTime.now();
  String userName = "";
  String userId = "";
  String empId = "";
  String userAccount = "";
  int _selectedNavIndex = 0;
  Map<String, dynamic>? attendanceData;
  Map<String, dynamic>? shiftData;

  // ==================== OFFLINE QUEUE ====================
  int _pendingCount = 0;

  // ==================== COLORS ====================
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

  // ==================== CONNECTION STATUS ====================
  ConnectionStatus _connectionStatus = ConnectionStatus.good;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _connectionTimer;
  bool _isCheckingConnection = false;
  bool _isAutoSyncing = false;
  final Connectivity _connectivity = Connectivity();

  static const Color kConnGood = Color(0xFF4CAF50);
  static const Color kConnWeak = Color(0xFFFF9800);
  static const Color kConnOffline = Color(0xFFF44336);

  // ==================== LIFECYCLE ====================
  @override
  void initState() {
    super.initState();
    _loadUserData().then((_) => _loadHomeData());
    _refreshPendingCount();
    _updateTime();
    _startConnectionMonitoring();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _connectionTimer?.cancel();
    super.dispose();
  }

  // ==================== TIME ====================
  void _updateTime() {
    if (!mounted) return;
    setState(() => _currentTime = DateTime.now());
    Future.delayed(const Duration(minutes: 1), _updateTime);
  }

  // ==================== USER DATA ====================
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userName = prefs.getString('empname') ?? "Karyawan";
      userId = prefs.getString('userid') ?? "";
      empId = prefs.getString('empid') ?? "";
      userAccount = prefs.getString('username') ?? "";
    });
  }

  Future<void> _loadHomeData() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final url = "$kBaseUrl/api/new_gethomedata?employeeid=$empId&date=$today";
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data']['employee'] != null) {
          if (!mounted) return;
          setState(() {
            attendanceData = json['data']['attendance'];
            shiftData = json['data']['shift'];
          });
        }
      }
    } catch (_) {
      // silent fail — biarkan data lama tetap tampil
    }
  }

  // ==================== OFFLINE QUEUE HELPERS ====================
  Future<void> _refreshPendingCount() async {
    final count = await OfflineService.pendingCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  Future<void> _openOfflineQueue() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OfflineAttendancePage(),
      ),
    );
    await _refreshPendingCount();
  }

  // ==================== CLOCK IN / OUT ====================
  Future<void> _clockIn(String base64image) async {
    final prefs = await SharedPreferences.getInstance();
    final empIdLocal = prefs.getString('empid') ?? "";
    final empName = prefs.getString('empname') ?? "";
    final now = DateTime.now();

    // ------------------------------------------------------------
    // KALAU OFFLINE → langsung simpan ke antrian
    // ------------------------------------------------------------
    if (_connectionStatus == ConnectionStatus.offline) {
      await OfflineService.enqueue(
        type: 'clock_in',
        employeeId: empIdLocal,
        employeeName: empName,
        base64Image: base64image,
        locationName: 'Office',
        locationAddress: 'Jl. ABC',
        locationCoordinate: '-6.2000,106.8166',
      );
      await _refreshPendingCount();
      return;
    }

    // ------------------------------------------------------------
    // ONLINE → coba kirim ke server
    // ------------------------------------------------------------
    final url = Uri.parse("$kBaseUrl/api/new_clockin");
    final body = {
      "id": "",
      "employeeid": empIdLocal,
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

    try {
      await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      // Gagal kirim → masukkan ke antrian sebagai fallback
      await OfflineService.enqueue(
        type: 'clock_in',
        employeeId: empIdLocal,
        employeeName: empName,
        base64Image: base64image,
        locationName: 'Office',
        locationAddress: 'Jl. ABC',
        locationCoordinate: '-6.2000,106.8166',
      );
      await _refreshPendingCount();
      rethrow;
    }
  }

  Future<void> _clockOut(String base64image) async {
    final prefs = await SharedPreferences.getInstance();
    final empIdLocal = prefs.getString('empid') ?? "";
    final empName = prefs.getString('empname') ?? "";
    final now = DateTime.now();

    if (_connectionStatus == ConnectionStatus.offline) {
      await OfflineService.enqueue(
        type: 'clock_out',
        employeeId: empIdLocal,
        employeeName: empName,
        base64Image: base64image,
        locationName: 'Office',
        locationAddress: 'Jl. ABC',
        locationCoordinate: '-6.2000,106.8166',
      );
      await _refreshPendingCount();
      return;
    }

    final url = Uri.parse("$kBaseUrl/api/new_clockout");
    final body = {
      "id": "",
      "employeeid": empIdLocal,
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

    try {
      await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      await OfflineService.enqueue(
        type: 'clock_out',
        employeeId: empIdLocal,
        employeeName: empName,
        base64Image: base64image,
        locationName: 'Office',
        locationAddress: 'Jl. ABC',
        locationCoordinate: '-6.2000,106.8166',
      );
      await _refreshPendingCount();
      rethrow;
    }
  }

  // ==================== CONNECTION MONITORING ====================
  void _startConnectionMonitoring() {
    _checkConnection();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final hasNetwork = _hasNetwork(results);
      if (!hasNetwork) {
        _updateConnectionStatus(ConnectionStatus.offline);
      } else {
        _checkConnection();
      }
    });

    _connectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkConnection(),
    );
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    if (results.contains(ConnectivityResult.none)) return false;
    return true;
  }

  Future<void> _checkConnection() async {
    if (_isCheckingConnection) return;
    _isCheckingConnection = true;

    try {
      final results = await _connectivity.checkConnectivity();
      if (!_hasNetwork(results)) {
        _updateConnectionStatus(ConnectionStatus.offline);
        return;
      }

      final latency = await _measureLatency();

      if (latency == null) {
        _updateConnectionStatus(ConnectionStatus.offline);
      } else if (latency < 500) {
        _updateConnectionStatus(ConnectionStatus.good);
      } else if (latency < 1500) {
        _updateConnectionStatus(ConnectionStatus.weak);
      } else {
        _updateConnectionStatus(ConnectionStatus.offline);
      }
    } catch (_) {
      _updateConnectionStatus(ConnectionStatus.offline);
    } finally {
      _isCheckingConnection = false;
    }
  }

  Future<int?> _measureLatency() async {
    final localLatency = await _pingUrl(kPingUrl);
    if (localLatency != null) return localLatency;

    final publicLatency = await _pingUrl(kPublicPingUrl);
    if (publicLatency != null) {
      return publicLatency + 800;
    }

    return null;
  }

  Future<int?> _pingUrl(String url) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response =
          await http.head(Uri.parse(url)).timeout(const Duration(seconds: 3));
      stopwatch.stop();

      if (response.statusCode >= 200 && response.statusCode < 400) {
        return stopwatch.elapsedMilliseconds;
      }
      return null;
    } catch (_) {
      stopwatch.stop();
      return null;
    }
  }

  void _updateConnectionStatus(ConnectionStatus status) {
    if (!mounted) return;
    final wasOffline = _connectionStatus == ConnectionStatus.offline;

    if (_connectionStatus != status) {
      setState(() => _connectionStatus = status);
    }

    // 🔥 Auto-sync saat baru kembali online & ada pending
    if (wasOffline && status != ConnectionStatus.offline) {
      _autoSyncPending();
    }
  }

  Future<void> _autoSyncPending() async {
    if (_isAutoSyncing) return;
    final count = await OfflineService.pendingCount();
    if (count == 0) return;

    _isAutoSyncing = true;
    try {
      final result = await OfflineService.syncAll();
      await _refreshPendingCount();

      if (!mounted) return;
      if (result.allSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.success} data absensi berhasil tersinkron'),
            backgroundColor: kSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        await OfflineService.clearSynced();
        await _refreshPendingCount();
        await _loadHomeData();
      }
    } finally {
      _isAutoSyncing = false;
    }
  }

  Color _getConnectionColor() {
    switch (_connectionStatus) {
      case ConnectionStatus.good:
        return kConnGood;
      case ConnectionStatus.weak:
        return kConnWeak;
      case ConnectionStatus.offline:
        return kConnOffline;
    }
  }

  String _getConnectionLabel() {
    switch (_connectionStatus) {
      case ConnectionStatus.good:
        return 'Online';
      case ConnectionStatus.weak:
        return 'Sinyal Lemah';
      case ConnectionStatus.offline:
        return 'Offline';
    }
  }

  IconData _getConnectionIcon() {
    switch (_connectionStatus) {
      case ConnectionStatus.good:
        return CupertinoIcons.wifi;
      case ConnectionStatus.weak:
        return CupertinoIcons.wifi_exclamationmark;
      case ConnectionStatus.offline:
        return CupertinoIcons.wifi_slash;
    }
  }

  // ==================== DIALOG ====================
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
                child:
                    const Icon(Icons.check_circle, color: kSuccess, size: 48),
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

  void _showOfflineDialog(String title, String message) {
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
                  color: kWarning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.tray_arrow_up_fill,
                    color: kWarning, size: 42),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Tutup"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _openOfflineQueue();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Lihat Antrian",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== NAVIGATION ====================
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
    if (index == 1 && empId.isEmpty) return;
    setState(() => _selectedNavIndex = index);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam';
  }

  // ==================== BUILD ====================
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
              ? const Center(child: CircularProgressIndicator())
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
        SliverToBoxAdapter(child: _buildOfflineBanner()),
        SliverToBoxAdapter(child: _buildCorePillars()),
        SliverToBoxAdapter(child: _buildMenuSection()),
        SliverToBoxAdapter(child: const AnnouncementSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
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
          colors: [kPrimary, kSecondary],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _getGreeting(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildConnectionIndicator(compact: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  userName.isNotEmpty ? userName : 'Karyawan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(_currentTime),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ==================== BADGE ANTRIAN ====================
          if (_pendingCount > 0)
            GestureDetector(
              onTap: _openOfflineQueue,
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.30),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.tray_arrow_up_fill,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      '$_pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
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

  // ==================== CONNECTION INDICATOR ====================
  Widget _buildConnectionIndicator({bool compact = false}) {
    final color = _getConnectionColor();

    if (compact) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(_getConnectionIcon(), size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              _getConnectionLabel(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(_getConnectionIcon(), size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            _getConnectionLabel(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== OFFLINE BANNER ====================
  Widget _buildOfflineBanner() {
    final isOffline = _connectionStatus == ConnectionStatus.offline;
    final hasPending = _pendingCount > 0;

    // Kalau online & tidak ada pending → sembunyikan
    if (!isOffline && !hasPending) return const SizedBox.shrink();

    final isOnlineSync = !isOffline && hasPending;
    final bannerColor = isOffline ? kConnOffline : kPrimary;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withOpacity(0.30), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOffline
                    ? CupertinoIcons.wifi_slash
                    : Icons.cloud_upload_rounded,
                color: bannerColor,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isOffline
                      ? 'Mode Offline. Absensi tetap bisa dilakukan & tersimpan lokal.'
                      : 'Ada $_pendingCount data absensi menunggu sinkron.',
                  style: const TextStyle(
                    color: kDarkText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (hasPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildPendingBadge()),
                const SizedBox(width: 8),
                if (isOnlineSync)
                  ElevatedButton.icon(
                    onPressed: _autoSyncPending,
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Sinkron'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  )
                else if (isOffline)
                  OutlinedButton.icon(
                    onPressed: _openOfflineQueue,
                    icon:
                        const Icon(CupertinoIcons.tray_arrow_up_fill, size: 16),
                    label: const Text('Lihat Antrian'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kConnOffline,
                      side: BorderSide(
                        color: kConnOffline.withOpacity(0.4),
                        width: 1,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_bottom_rounded, color: kWarning, size: 14),
          const SizedBox(width: 6),
          Text(
            '$_pendingCount data tertunda',
            style: const TextStyle(
              color: kDarkText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FORMAT TIME ====================
  String _formatHHmm(dynamic raw) {
    if (raw == null) return '-';
    final s = raw.toString().trim();
    if (s.isEmpty) return '-';
    final parts = s.split(':');
    if (parts.length >= 2) {
      final hh = parts[0].padLeft(2, '0');
      final mm = parts[1].padLeft(2, '0');
      return '$hh:$mm';
    }
    try {
      final dt = DateTime.parse(s);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return s;
    }
  }

  // ==================== SHIFT CARD ====================
  Widget _buildShiftCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder, width: 1),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.schedule_rounded, color: kPrimary, size: 16),
                    SizedBox(width: 7),
                    Text(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      _formatHHmm(shiftData?['schedulein']),
                      style: const TextStyle(
                        color: kDarkText,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 44, color: kBorder),
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
                        _formatHHmm(shiftData?['scheduleout']),
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
          Row(
            children: [
              // ==================== CLOCK IN ====================
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
                            const CheckLocationPage(isCheckIn: true),
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

                    if (photo == null) return;

                    final bytes = await photo.readAsBytes();
                    final base64Image = base64Encode(bytes);

                    final wasOffline =
                        _connectionStatus == ConnectionStatus.offline;

                    try {
                      await _clockIn(base64Image);

                      if (wasOffline) {
                        _showOfflineDialog(
                          "Check In Tersimpan (Offline)",
                          "Data absensi Anda sudah tersimpan di perangkat. "
                              "Akan otomatis terkirim saat koneksi kembali.",
                        );
                      } else {
                        _showSuccessDialog(
                          "Check In Berhasil",
                          "Anda berhasil melakukan Check In.",
                        );
                        await _loadHomeData();
                      }
                    } catch (_) {
                      // Gagal kirim → sudah di-enqueue di dalam _clockIn
                      _showOfflineDialog(
                        "Check In Tersimpan (Gagal Kirim)",
                        "Koneksi terputus. Data sudah disimpan lokal "
                            "dan akan dikirim otomatis nanti.",
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),

              // ==================== CLOCK OUT ====================
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
                            const CheckLocationPage(isCheckIn: false),
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

                    if (photo == null) return;

                    final bytes = await photo.readAsBytes();
                    final base64Image = base64Encode(bytes);

                    final wasOffline =
                        _connectionStatus == ConnectionStatus.offline;

                    try {
                      await _clockOut(base64Image);

                      if (wasOffline) {
                        _showOfflineDialog(
                          "Check Out Tersimpan (Offline)",
                          "Data absensi Anda sudah tersimpan di perangkat. "
                              "Akan otomatis terkirim saat koneksi kembali.",
                        );
                      } else {
                        _showSuccessDialog(
                          "Check Out Berhasil",
                          "Anda berhasil melakukan Check Out.",
                        );
                        await _loadHomeData();
                      }
                    } catch (_) {
                      _showOfflineDialog(
                        "Check Out Tersimpan (Gagal Kirim)",
                        "Koneksi terputus. Data sudah disimpan lokal "
                            "dan akan dikirim otomatis nanti.",
                      );
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
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: color.withOpacity(0.12), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
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

  // ==================== CORE PILLARS ====================
  Widget _buildCorePillars() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Center(
        child: Image.asset(
          'assets/images/core.png',
          width: MediaQuery.of(context).size.width * 0.62,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ==================== MENU SECTION ====================
  Widget _buildMenuSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder, width: 1),
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TimeOffPage(),
                          ),
                        );
                      },
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ApprovalPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _buildMenuItem(
                      icon: CupertinoIcons.tray_arrow_up_fill,
                      title: 'Antrian',
                      color: kConnWeak,
                      onTap: _openOfflineQueue,
                      badge: _pendingCount,
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
    int badge = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
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
                  border: Border.all(color: color.withOpacity(0.08), width: 1),
                ),
                child: Center(
                  child: Icon(icon, size: 27, color: color),
                ),
              ),
              if (badge > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kConnOffline,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      badge > 99 ? '99+' : badge.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
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

  // ==================== BOTTOM NAV ====================
  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: kBorder, width: 1),
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
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
