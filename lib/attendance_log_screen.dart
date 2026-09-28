import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'attendance_home.dart';

// ====== HELPER TAMPILAN JAM (HH:MM tanpa detik) ======
String _formatHHmm(String time) {
  if (time == 'no record') return time;
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(time);
  if (match == null) return time;
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

class AttendanceLogScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const AttendanceLogScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<AttendanceLogScreen> createState() => _AttendanceLogScreenState();
}

class _AttendanceLogScreenState extends State<AttendanceLogScreen> {
  // Data
  List<AttendanceData> attendanceLogs = [];
  bool isLoading = true;
  DateTime selectedMonth = DateTime.now();
  String filterStatus = 'Semua';
  DateTime? startDate;
  DateTime? endDate;

  // Theme colors (putih & biru)
  static const primaryColor = Color(0xFF1D4ED8);
  static const secondaryColor = Color(0xFF0B2A6F);
  static const accentColor = Color(0xFF3B82F6);
  static const softBlue = Color(0xFFEAF1FF);
  static const backgroundColor = Color(0xFFF5F8FF);
  static const textDark = Color(0xFF0F1B3D);
  static const textMuted = Color(0xFF6B7A99);
  static const outColor = Color(0xFF3949AB);

  @override
  void initState() {
    super.initState();
    _calculatePeriod();
    fetchAttendanceLogs();
  }

  void _calculatePeriod() {
    DateTime previousMonth;
    if (selectedMonth.month == 1) {
      previousMonth = DateTime(selectedMonth.year - 1, 12, 16);
    } else {
      previousMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 16);
    }
    startDate = previousMonth;
    endDate = DateTime(selectedMonth.year, selectedMonth.month, 15);
  }

  Future<void> fetchAttendanceLogs() async {
    try {
      setState(() => isLoading = true);

      String startStr = DateFormat('yyyy-MM-dd').format(startDate!);
      String endStr = DateFormat('yyyy-MM-dd').format(endDate!);

      final response = await http.get(
        Uri.parse('http://localhost:8000/api/new_getAttendLogByEmpIdPeriod')
            .replace(queryParameters: {
          'empid': widget.employeeId,
          'start': startStr,
          'end': endStr,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          List<dynamic> rawData = decoded['data'] ?? [];
          List<AttendanceData> processedData = _processRawData(rawData);

          setState(() {
            attendanceLogs = _filterData(processedData);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<AttendanceData> _processRawData(List<dynamic> rawData) {
    Map<String, AttendanceData> groupedData = {};

    for (var item in rawData) {
      String date = item['DateValue']?.toString() ?? '';
      if (date.isEmpty) continue;

      if (!groupedData.containsKey(date)) {
        groupedData[date] = AttendanceData.fromJson(item);
      } else {
        AttendanceData existing = groupedData[date]!;
        groupedData[date] = existing.merge(item);
      }
    }

    List<AttendanceData> result = groupedData.values.toList();
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  List<AttendanceData> _filterData(List<AttendanceData> data) {
    if (filterStatus == 'Semua') return data;

    return data.where((item) {
      return item.status.toLowerCase().contains(filterStatus.toLowerCase());
    }).toList();
  }

  String _getPeriodName() => DateFormat('MMMM yyyy').format(selectedMonth);
  String _getPeriodRange() =>
      '${DateFormat('dd MMM').format(startDate!)} - ${DateFormat('dd MMM yyyy').format(endDate!)}';

  // ====== HELPER DEKORASI ======
  BoxDecoration _cardDecoration({double radius = 20}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: primaryColor.withOpacity(0.07)),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withOpacity(0.10),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [secondaryColor, primaryColor, accentColor],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIconButton(Icons.arrow_back_ios_new, () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage()),
                      (route) => false,
                    );
                  }),
                  const Text(
                    'Riwayat Absensi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                  _buildIconButton(Icons.refresh_rounded, fetchAttendanceLogs),
                ],
              ),
              const SizedBox(height: 14),
              _buildPeriodSelector(),
              const SizedBox(height: 12),
              _buildNavigationRow(),
              const SizedBox(height: 12),
              _buildStatsBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return GestureDetector(
      onTap: () => _showMonthYearPicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded,
                color: Colors.white, size: 17),
            const SizedBox(width: 8),
            Text(
              _getPeriodName(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildNavButton(Icons.chevron_left, _goToPreviousMonth),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _getPeriodRange(),
            style: const TextStyle(
              fontSize: 11.5,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _buildNavButton(Icons.chevron_right, _goToNextMonth),
      ],
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 18),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      ),
    );
  }

  Widget _buildStatsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_view_day, size: 13, color: primaryColor),
          const SizedBox(width: 5),
          Text(
            '${attendanceLogs.length} Hari',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 18),
        onPressed: onTap,
        padding: const EdgeInsets.all(7),
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: _cardDecoration(radius: 14),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: filterStatus,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                  icon: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: softBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.filter_list_rounded,
                        color: primaryColor, size: 18),
                  ),
                  items: [
                    'Semua',
                    'Present',
                    'Waiting Approval',
                    'Rejected',
                    'Absent'
                  ]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => filterStatus = value!);
                    fetchAttendanceLogs();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 14),
            Text('Memuat data...', style: TextStyle(color: textMuted)),
          ],
        ),
      );
    }

    if (attendanceLogs.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: attendanceLogs.length,
      itemBuilder: (context, index) =>
          _buildAttendanceCard(attendanceLogs[index]),
    );
  }

  Widget _buildAttendanceCard(AttendanceData data) {
    bool isHoliday = data.dayType == DayType.holiday;
    bool isDayOff = data.dayType == DayType.dayOff;
    bool isSpecial = isHoliday || isDayOff;

    Color cardAccent =
        isHoliday ? Colors.red : (isDayOff ? Colors.orange : primaryColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showDetailDialog(data),
          child: Container(
            decoration: _cardDecoration(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildDateWidget(data, isSpecial, cardAccent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCardContent(data, isSpecial, cardAccent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetailDialog(AttendanceData data) async {
    String? checkinPhotoBase64;
    String? checkoutPhotoBase64;

    // ===== 1. FETCH FOTO =====
    if (data.attendanceId != null &&
        data.attendanceId!.isNotEmpty &&
        data.attendanceId != 'null') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );

      try {
        final photos = await _fetchActivityPhotos(data.attendanceId!);
        checkinPhotoBase64 = photos['checkin'];
        checkoutPhotoBase64 = photos['checkout'];
      } catch (e) {
        debugPrint('Error fetching photos: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memuat foto: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } finally {
        if (mounted && Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    }

    if (!mounted) return;

    // ===== 2. TAMPILKAN DIALOG DETAIL =====
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== HEADER =====
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [secondaryColor, primaryColor, accentColor],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data.dayName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.35)),
                          ),
                          child: Text(
                            data.dayTypeText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        DateFormat('dd MMMM yyyy').format(data.date),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    if (data.shift != null && data.shift!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Shift: ${data.shift}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ===== BODY =====
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildDetailSection(
                        title: 'CHECK IN',
                        time: data.checkinTime,
                        photoBase64: checkinPhotoBase64,
                        isLate: data.isLateIn,
                        icon: Icons.login_rounded,
                        color: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailSection(
                        title: 'CHECK OUT',
                        time: data.checkoutTime,
                        photoBase64: checkoutPhotoBase64,
                        isLate: data.isEarlyOut,
                        icon: Icons.logout_rounded,
                        color: outColor,
                      ),
                      if (data.timeoffName != null &&
                          data.timeoffName!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: softBlue,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: primaryColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_note,
                                  color: primaryColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Keterangan',
                                      style: TextStyle(
                                          fontSize: 11, color: textMuted),
                                    ),
                                    Text(
                                      data.timeoffName!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _getStatusColor(data.status).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                _getStatusColor(data.status).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(data.status),
                              color: _getStatusColor(data.status),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Status',
                                    style: TextStyle(
                                        fontSize: 11, color: textMuted),
                                  ),
                                  Text(
                                    data.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _getStatusColor(data.status),
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
              ),

              // ===== CLOSE BUTTON =====
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: softBlue, width: 1.5)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      elevation: 3,
                      shadowColor: primaryColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fetch foto check-in & check-out dari activity attendance.
  Future<Map<String, String?>> _fetchActivityPhotos(String attendanceId) async {
    final Map<String, String?> result = {
      'checkin': null,
      'checkout': null,
    };

    final activityResponse = await http.get(
      Uri.parse('http://localhost:8000/api/getattactbyattenid')
          .replace(queryParameters: {'id': attendanceId}),
    );

    if (activityResponse.statusCode != 200) {
      debugPrint(
          '[fetchPhotos] activity status: ${activityResponse.statusCode}');
      return result;
    }

    final activityDecoded = jsonDecode(activityResponse.body);
    if (activityDecoded['success'] != true || activityDecoded['data'] == null) {
      debugPrint(
          '[fetchPhotos] activity response invalid: ${activityResponse.body}');
      return result;
    }

    final List<dynamic> activities = activityDecoded['data'];
    debugPrint('[fetchPhotos] total activities: ${activities.length}');

    for (final activity in activities) {
      final String rawType = activity['type']?.toString() ?? '';
      final String type = rawType.toUpperCase();
      final String? photoFilename = activity['attendphoto']?.toString();

      debugPrint('[fetchPhotos] type="$rawType" | photo="$photoFilename"');

      if (photoFilename == null || photoFilename.isEmpty) continue;

      try {
        final photoResponse = await http.get(
          Uri.parse('http://localhost:8000/api/getattendphoto')
              .replace(queryParameters: {'filename': photoFilename}),
        );

        if (photoResponse.statusCode != 200) {
          debugPrint('[fetchPhotos] photo status: ${photoResponse.statusCode}');
          continue;
        }

        final photoDecoded = jsonDecode(photoResponse.body);
        if (photoDecoded['success'] != true) {
          debugPrint('[fetchPhotos] photo failed: ${photoResponse.body}');
          continue;
        }

        final String? base64Data = photoDecoded['data']?.toString();
        if (base64Data == null || base64Data.isEmpty) continue;

        if (type.contains('OUT')) {
          result['checkout'] = base64Data;
        } else if (type.contains('IN')) {
          result['checkin'] = base64Data;
        }
      } catch (e) {
        debugPrint('[fetchPhotos] error on $photoFilename: $e');
      }
    }

    debugPrint('[fetchPhotos] DONE → checkin: ${result['checkin'] != null}, '
        'checkout: ${result['checkout'] != null}');

    return result;
  }

  // ===== DIALOG FOTO FULLSCREEN =====
  void _showZoomablePhoto(String base64Image, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (context) => _ZoomablePhotoViewer(
        base64Image: base64Image,
        title: title,
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required String time,
    required String? photoBase64,
    required bool isLate,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const Spacer(),
                if (isLate && time != 'no record')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          title == 'CHECK IN' ? 'Terlambat' : 'Pulang Cepat',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  // Time
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        const Text(
                          'Waktu',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          time == 'no record'
                              ? 'Belum ada record'
                              : _formatHHmm(time),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: time == 'no record' ? Colors.grey : color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Photo
                  if (photoBase64 != null && photoBase64.isNotEmpty)
                    Column(
                      children: [
                        const Divider(color: softBlue, thickness: 1.5),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Foto',
                              style: TextStyle(fontSize: 11, color: textMuted),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.zoom_in_rounded,
                                size: 12, color: textMuted),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: color.withOpacity(0.4), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              children: [
                                // Foto dengan gesture tap
                                Positioned.fill(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _showZoomablePhoto(photoBase64, title),
                                    child: Hero(
                                      tag: 'photo_$title',
                                      child: Image.memory(
                                        base64Decode(photoBase64),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: softBlue,
                                            child: Icon(Icons.broken_image,
                                                size: 40, color: textMuted),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                // Badge zoom di pojok kanan atas
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.zoom_out_map_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (time != 'no record')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: softBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.no_photography,
                                size: 20, color: textMuted),
                            SizedBox(width: 8),
                            Text(
                              'Tidak ada foto',
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'present':
        return Colors.green;
      case 'waiting approval':
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'absent':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'present':
        return Icons.check_circle_outline;
      case 'waiting approval':
      case 'pending':
        return Icons.pending_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'absent':
        return Icons.do_not_disturb_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildDateWidget(AttendanceData data, bool isSpecial, Color accent) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSpecial
              ? [accent, accent.withOpacity(0.7)]
              : [secondaryColor, primaryColor],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            data.dayNumber,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            data.shortMonth.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(AttendanceData data, bool isSpecial, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.dayName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.formattedDate,
                    style: const TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
            ),
            _buildBadge(data.dayTypeText, accent),
          ],
        ),
        const SizedBox(height: 12),
        if (isSpecial)
          _buildSpecialDayWidget(data, accent)
        else
          _buildTimeWidgets(data),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildSpecialDayWidget(AttendanceData data, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
              data.dayType == DayType.holiday
                  ? Icons.celebration
                  : Icons.beach_access,
              size: 20,
              color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              data.dayType == DayType.holiday
                  ? 'HARI LIBUR NASIONAL'
                  : 'HARI OFF',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: accent),
            ),
          ),
          if (data.timeoffName != null)
            Text(
              data.timeoffName!,
              style: TextStyle(fontSize: 11, color: accent),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeWidgets(AttendanceData data) {
    return Row(
      children: [
        Expanded(
            child: _buildTimeCard(
                Icons.login, 'Masuk', data.checkinTime, primaryColor)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildTimeCard(
                Icons.logout, 'Keluar', data.checkoutTime, outColor)),
      ],
    );
  }

  Widget _buildTimeCard(IconData icon, String label, String time, Color color) {
    bool hasNoRecord = time == 'no record';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: textMuted)),
                Text(
                  hasNoRecord ? 'Belum absen' : _formatHHmm(time),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasNoRecord ? Colors.grey : color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: softBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_edu, size: 64, color: accentColor),
          ),
          const SizedBox(height: 18),
          const Text(
            'Belum Ada Data Absensi',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Periode ${_getPeriodName()}',
            style: const TextStyle(fontSize: 14, color: textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() => selectedMonth = DateTime.now());
              _calculatePeriod();
              fetchAttendanceLogs();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              elevation: 3,
              shadowColor: primaryColor.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
            ),
            child: const Text('Tampilkan Bulan Ini',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMonthYearPicker() async {
    int currentYear = DateTime.now().year;
    List<int> years = List.generate(5, (index) => currentYear - index);
    List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];

    int selectedYear = selectedMonth.year;
    int selectedMonthIndex = selectedMonth.month;

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Container(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: softBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: primaryColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Pilih Periode',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: secondaryColor)),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: softBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedYear,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: primaryColor),
                    items: years
                        .map((y) => DropdownMenuItem(
                            value: y, child: Text(y.toString())))
                        .toList(),
                    onChanged: (v) => selectedYear = v!,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  int monthIndex = index + 1;
                  bool isSelected = monthIndex == selectedMonthIndex;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(
                        context, DateTime(selectedYear, monthIndex, 1)),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [secondaryColor, primaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : softBlue,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          months[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : textDark,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal',
                      style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    ).then((value) {
      if (value != null && value != selectedMonth) {
        setState(() => selectedMonth = value);
        _calculatePeriod();
        fetchAttendanceLogs();
      }
    });
  }

  void _goToPreviousMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
      _calculatePeriod();
      fetchAttendanceLogs();
    });
  }

  void _goToNextMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
      _calculatePeriod();
      fetchAttendanceLogs();
    });
  }
}

// ============================================================
// WIDGET ZOOM PHOTO VIEWER (FULLSCREEN)
// ============================================================
class _ZoomablePhotoViewer extends StatefulWidget {
  final String base64Image;
  final String title;

  const _ZoomablePhotoViewer({
    required this.base64Image,
    required this.title,
  });

  @override
  State<_ZoomablePhotoViewer> createState() => _ZoomablePhotoViewerState();
}

class _ZoomablePhotoViewerState extends State<_ZoomablePhotoViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  late AnimationController _animationController;
  late Animation<Matrix4> _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = Matrix4Tween(
      begin: Matrix4.identity(),
      end: Matrix4.identity(),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.addListener(() {
      _transformController.value = _animation.value;
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();

    if (currentScale > 1.0) {
      // Zoom out ke normal
      _animateTo(Matrix4.identity());
    } else {
      // Zoom in ke 2.5x di posisi tap
      const scale = 2.5;
      final position = _doubleTapDetails!.localPosition;

      final matrix = Matrix4.identity()
        ..translate(-position.dx * (scale - 1), -position.dy * (scale - 1))
        ..scale(scale);

      _animateTo(matrix);
    }
  }

  void _animateTo(Matrix4 target) {
    _animation = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // ===== FOTO ZOOMABLE =====
          Positioned.fill(
            child: GestureDetector(
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 1.0,
                maxScale: 5.0,
                boundaryMargin: const EdgeInsets.all(20),
                clipBehavior: Clip.none,
                child: Center(
                  child: Hero(
                    tag: 'photo_${widget.title}',
                    child: Image.memory(
                      base64Decode(widget.base64Image),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image,
                                  size: 64, color: Colors.white54),
                              SizedBox(height: 12),
                              Text(
                                'Gagal memuat foto',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ===== TOMBOL CLOSE =====
          Positioned(
            top: 40,
            right: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // ===== LABEL TITLE =====
          Positioned(
            top: 48,
            left: 20,
            right: 80,
            child: SafeArea(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===== HINT =====
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pinch_rounded,
                          color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Cubit untuk zoom • Double tap untuk perbesar',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DATA MODELS
// ============================================================
enum DayType { workDay, dayOff, holiday }

class AttendanceData {
  final DateTime date;
  final String checkinTime;
  final String checkoutTime;
  final String status;
  final DayType dayType;
  final String? timeoffName;
  final String? attendanceId;
  final String? shift;
  final bool isLateIn;
  final bool isEarlyOut;

  AttendanceData({
    required this.date,
    required this.checkinTime,
    required this.checkoutTime,
    required this.status,
    required this.dayType,
    this.timeoffName,
    this.attendanceId,
    this.shift,
    this.isLateIn = false,
    this.isEarlyOut = false,
  });

  factory AttendanceData.fromJson(Map<String, dynamic> json) {
    DateTime date =
        DateTime.parse(json['DateValue'] ?? DateTime.now().toString());
    String shiftFlag = json['shiftflag']?.toString().toLowerCase() ?? 'w';
    String? timeoff = json['timeoffname']?.toString();

    DayType dayType = _determineDayType(shiftFlag, date, timeoff);

    return AttendanceData(
      date: date,
      checkinTime: json['checkin']?.toString() ?? 'no record',
      checkoutTime: json['checkout']?.toString() ?? 'no record',
      status: json['status']?.toString() ?? 'Unknown',
      dayType: dayType,
      timeoffName: timeoff,
      attendanceId: json['attendanceid']?.toString(),
      shift: json['shift']?.toString(),
      isLateIn: json['islatein'] == 1 || json['islatein'] == true,
      isEarlyOut: json['isearlyout'] == 1 || json['isearlyout'] == true,
    );
  }

  static DayType _determineDayType(
      String shiftFlag, DateTime date, String? timeoff) {
    if (shiftFlag == 'h' ||
        shiftFlag == 'holiday' ||
        shiftFlag.contains('holiday')) {
      return DayType.holiday;
    }
    if (shiftFlag == 'o' || shiftFlag == 'off' || shiftFlag.contains('off')) {
      return DayType.dayOff;
    }
    if (timeoff != null &&
        (timeoff.contains('natal') || timeoff.contains('libur'))) {
      return DayType.holiday;
    }
    if (date.weekday == 6 || date.weekday == 7) {
      return DayType.dayOff;
    }
    return DayType.workDay;
  }

  AttendanceData merge(Map<String, dynamic> newData) {
    String newCheckin = newData['checkin']?.toString() ?? checkinTime;
    String newCheckout = newData['checkout']?.toString() ?? checkoutTime;
    String newStatus = newData['status']?.toString() ?? status;

    return AttendanceData(
      date: date,
      checkinTime: _getEarlierTime(checkinTime, newCheckin),
      checkoutTime: _getLaterTime(checkoutTime, newCheckout),
      status: _getHigherPriorityStatus(status, newStatus),
      dayType: dayType,
      timeoffName: timeoffName ?? newData['timeoffname']?.toString(),
    );
  }

  String _getEarlierTime(String t1, String t2) {
    if (t1 == 'no record') return t2;
    if (t2 == 'no record') return t1;
    return t1.compareTo(t2) < 0 ? t1 : t2;
  }

  String _getLaterTime(String t1, String t2) {
    if (t1 == 'no record') return t2;
    if (t2 == 'no record') return t1;
    return t1.compareTo(t2) > 0 ? t1 : t2;
  }

  String _getHigherPriorityStatus(String s1, String s2) {
    int priority(String s) {
      switch (s.toLowerCase()) {
        case 'approved':
          return 4;
        case 'waiting approval':
          return 3;
        case 'rejected':
          return 2;
        case 'absent':
          return 1;
        default:
          return 0;
      }
    }

    return priority(s1) > priority(s2) ? s1 : s2;
  }

  String get dayName => DateFormat('EEEE').format(date);
  String get dayNumber => DateFormat('d').format(date);
  String get shortMonth => DateFormat('MMM').format(date);
  String get formattedDate => DateFormat('d MMM yyyy').format(date);

  String get dayTypeText {
    switch (dayType) {
      case DayType.holiday:
        return 'LIBUR';
      case DayType.dayOff:
        return 'OFF';
      case DayType.workDay:
        return 'KERJA';
    }
  }
}

class AttendanceDetail {
  final String attendanceId;
  final String checkinTime;
  final String checkoutTime;
  final String status;
  final String? checkinPhoto;
  final String? checkoutPhoto;
  final bool isLateIn;
  final bool isEarlyOut;
  final String? timeoffName;
  final String shift;

  AttendanceDetail({
    required this.attendanceId,
    required this.checkinTime,
    required this.checkoutTime,
    required this.status,
    this.checkinPhoto,
    this.checkoutPhoto,
    required this.isLateIn,
    required this.isEarlyOut,
    this.timeoffName,
    required this.shift,
  });

  factory AttendanceDetail.fromJson(Map<String, dynamic> json) {
    return AttendanceDetail(
      attendanceId: json['attendanceid']?.toString() ?? '',
      checkinTime: json['checkin']?.toString() ?? 'no record',
      checkoutTime: json['checkout']?.toString() ?? 'no record',
      status: json['status']?.toString() ?? 'Unknown',
      checkinPhoto: json['checkin_photo'],
      checkoutPhoto: json['checkout_photo'],
      isLateIn: json['islatein'] == 1 || json['islatein'] == true,
      isEarlyOut: json['isearlyout'] == 1 || json['isearlyout'] == true,
      timeoffName: json['timeoffname']?.toString(),
      shift: json['shift']?.toString() ?? '-',
    );
  }
}
