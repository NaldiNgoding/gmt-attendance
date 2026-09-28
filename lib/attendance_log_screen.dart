import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'attendance_home.dart';

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

  // Theme colors
  static const primaryColor = Color(0xFF1E88E5);
  static const secondaryColor = Color(0xFF0D47A1);
  static const backgroundColor = Color(0xFFF8F9FA);

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
        Uri.parse(
                'http://localhost:8000/api/getattendancelogbyempidandperiod')
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

  Future<Map<String, String?>> _fetchPhotos(String attendanceId) async {
    Map<String, String?> photos = {
      'checkin': null,
      'checkout': null,
    };

    try {
      // Panggil endpoint getattactbyattenid dengan parameter id = attendanceId
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/getattactbyattenid')
            .replace(queryParameters: {'id': attendanceId}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          List<dynamic> activities = decoded['data'];

          for (var activity in activities) {
            String type = activity['type']?.toString().toUpperCase() ?? '';
            String? photoFilename = activity['attendphoto'];

            if (photoFilename != null && photoFilename.isNotEmpty) {
              // Ambil file foto dari storage
              final photoResponse = await http.get(
                Uri.parse('http://localhost:8000/api/getattendphoto')
                    .replace(queryParameters: {'filename': photoFilename}),
              );

              if (photoResponse.statusCode == 200) {
                final photoDecoded = jsonDecode(photoResponse.body);
                if (photoDecoded['success'] == true) {
                  if (type == 'IN') {
                    photos['checkin'] = photoDecoded['data'];
                  } else if (type == 'OUT') {
                    photos['checkout'] = photoDecoded['data'];
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching photos: $e');
    }

    return photos;
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 16), // Kurangi padding top dari 12 ke 8
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
                  Text(
                    'Riwayat Absensi',
                    style: TextStyle(
                      fontSize: 18, // Kurangi dari 20 ke 18
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  _buildIconButton(Icons.refresh, fetchAttendanceLogs),
                ],
              ),
              SizedBox(height: 12), // Kurangi dari 16 ke 12
              _buildPeriodSelector(),
              SizedBox(height: 12), // Kurangi dari 16 ke 12
              _buildNavigationRow(),
              SizedBox(height: 10), // Kurangi dari 12 ke 10
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
        padding: EdgeInsets.symmetric(
            horizontal: 16, vertical: 8), // Kurangi vertical dari 10 ke 8
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(25), // Kurangi dari 30 ke 25
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today,
                color: Colors.white, size: 16), // Kurangi dari 18 ke 16
            SizedBox(width: 8), // Kurangi dari 10 ke 8
            Text(
              _getPeriodName(),
              style: TextStyle(
                fontSize: 14, // Kurangi dari 16 ke 14
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: Colors.white, size: 20), // Kurangi dari default ke 20
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
          padding: EdgeInsets.symmetric(
              horizontal: 12, vertical: 6), // Kurangi padding
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16), // Kurangi dari 20 ke 16
          ),
          child: Text(
            _getPeriodRange(),
            style: TextStyle(
                fontSize: 11, color: Colors.white), // Kurangi dari 12 ke 11
          ),
        ),
        _buildNavButton(Icons.chevron_right, _goToNextMonth),
      ],
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon:
            Icon(icon, color: Colors.white, size: 18), // Kurangi dari 20 ke 18
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
            width: 32, height: 32), // Kurangi dari 36 ke 32
      ),
    );
  }

  Widget _buildStatsBadge() {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Kurangi padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // Kurangi dari 20 ke 16
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_view_day,
              size: 12, color: primaryColor), // Kurangi dari 14 ke 12
          SizedBox(width: 4), // Kurangi dari 6 ke 4
          Text(
            '${attendanceLogs.length} Hari',
            style: TextStyle(
              fontSize: 11, // Kurangi dari 12 ke 11
              fontWeight: FontWeight.w600,
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
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon:
            Icon(icon, color: Colors.white, size: 18), // Kurangi dari 20 ke 18
        onPressed: onTap,
        padding: EdgeInsets.all(6), // Kurangi dari 8 ke 6
        constraints: BoxConstraints(),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: filterStatus,
                  isExpanded: true,
                  icon: Icon(Icons.filter_list, color: primaryColor),
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
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 12),
            Text('Memuat data...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (attendanceLogs.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () =>
              _showDetailDialog(data), // Tambahkan ini untuk membuka dialog
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildDateWidget(data, isSpecial, cardAccent),
                  SizedBox(width: 16),
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

    // Fetch photos from attendance activity
    if (data.attendanceId != null &&
        data.attendanceId!.isNotEmpty &&
        data.attendanceId != 'null') {
      try {
        // Tampilkan loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(color: primaryColor),
          ),
        );

        // 1. Ambil data activity berdasarkan attendid (id dari web_att_attendance)
        final activityResponse = await http.get(
          Uri.parse('http://localhost:8000/api/getattactbyattenid')
              .replace(queryParameters: {'id': data.attendanceId!}),
        );

        if (activityResponse.statusCode == 200) {
          final activityDecoded = jsonDecode(activityResponse.body);
          if (activityDecoded['success'] == true &&
              activityDecoded['data'] != null) {
            List<dynamic> activities = activityDecoded['data'];

            // Loop melalui semua activity (biasanya ada 2: IN dan OUT)
            for (var activity in activities) {
              String type = activity['type']?.toString().toUpperCase() ?? '';
              String? photoFilename = activity['attendphoto']; // Nama file foto
              String? checktime =
                  activity['checktime']; // Waktu checkin/checkout

              if (photoFilename != null && photoFilename.isNotEmpty) {
                // 2. Ambil file foto dari storage menggunakan endpoint getattendphoto
                final photoResponse = await http.get(
                  Uri.parse('http://localhost:8000/api/getattendphoto')
                      .replace(queryParameters: {'filename': photoFilename}),
                );

                if (photoResponse.statusCode == 200) {
                  final photoDecoded = jsonDecode(photoResponse.body);
                  if (photoDecoded['success'] == true) {
                    if (type == 'IN') {
                      checkinPhotoBase64 = photoDecoded['data'];
                      // Optional: update waktu checkin dari activity jika lebih akurat
                      if (checktime != null && checktime.isNotEmpty) {
                        // data.checkinTime = checktime; // Jika perlu update waktu
                      }
                    } else if (type == 'OUT') {
                      checkoutPhotoBase64 = photoDecoded['data'];
                      // Optional: update waktu checkout dari activity jika lebih akurat
                      if (checktime != null && checktime.isNotEmpty) {
                        // data.checkoutTime = checktime; // Jika perlu update waktu
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Navigator.pop(context); // Tutup loading
      } catch (e) {
        Navigator.pop(context); // Tutup loading jika error
        print('Error fetching photos: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat foto: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    // Tampilkan dialog detail (sama seperti sebelumnya)
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, secondaryColor],
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            data.dayTypeText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      DateFormat('dd MMMM yyyy').format(data.date),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    if (data.shift != null && data.shift!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Shift: ${data.shift}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Check In Section
                      _buildDetailSection(
                        title: 'CHECK IN',
                        time: data.checkinTime,
                        photoBase64: checkinPhotoBase64,
                        isLate: data.isLateIn,
                        icon: Icons.login_rounded,
                        color: Colors.green,
                      ),
                      SizedBox(height: 16),
                      // Check Out Section
                      _buildDetailSection(
                        title: 'CHECK OUT',
                        time: data.checkoutTime,
                        photoBase64: checkoutPhotoBase64,
                        isLate: data.isEarlyOut,
                        icon: Icons.logout_rounded,
                        color: Colors.orange,
                      ),
                      // Timeoff Info
                      if (data.timeoffName != null &&
                          data.timeoffName!.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(top: 16),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_note,
                                  color: Colors.blue, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Keterangan',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                    Text(
                                      data.timeoffName!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 16),
                      // Status Section
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getStatusColor(data.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
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
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                  Text(
                                    data.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
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
              // Close Button
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Spacer(),
                if (isLate && time != 'no record')
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 12, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          title == 'CHECK IN' ? 'Terlambat' : 'Pulang Cepat',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
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
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Time
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Text(
                        'Waktu',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      SizedBox(height: 4),
                      Text(
                        time == 'no record' ? 'Belum ada record' : time,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
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
                      Divider(),
                      SizedBox(height: 12),
                      Text(
                        'Foto',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(photoBase64),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade100,
                                child: Icon(Icons.broken_image,
                                    size: 40, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  )
                else if (time != 'no record')
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.no_photography,
                              size: 20, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            'Tidak ada foto',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSpecial
              ? [accent, accent.withOpacity(0.7)]
              : [primaryColor, secondaryColor],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            data.dayNumber,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            data.shortMonth.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.w500),
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
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  SizedBox(height: 4),
                  Text(
                    data.formattedDate,
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            _buildBadge(data.dayTypeText, accent),
          ],
        ),
        SizedBox(height: 12),
        if (isSpecial)
          _buildSpecialDayWidget(data, accent)
        else
          _buildTimeWidgets(data),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
              data.dayType == DayType.holiday
                  ? Icons.celebration
                  : Icons.beach_access,
              size: 20,
              color: accent),
          SizedBox(width: 10),
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
                Icons.login, 'Masuk', data.checkinTime, Colors.green)),
        SizedBox(width: 12),
        Expanded(
            child: _buildTimeCard(
                Icons.logout, 'Keluar', data.checkoutTime, Colors.orange)),
      ],
    );
  }

  Widget _buildTimeCard(IconData icon, String label, String time, Color color) {
    bool hasNoRecord = time == 'no record';

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text(
                  hasNoRecord ? 'Belum absen' : time,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
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
          Icon(Icons.history_edu, size: 80, color: Colors.grey.shade300),
          SizedBox(height: 16),
          Text(
            'Belum Ada Data Absensi',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Periode ${_getPeriodName()}',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() => selectedMonth = DateTime.now());
              _calculatePeriod();
              fetchAttendanceLogs();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Tampilkan Bulan Ini', style: TextStyle(fontSize: 14)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pilih Periode',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedYear,
                    isExpanded: true,
                    items: years
                        .map((y) => DropdownMenuItem(
                            value: y, child: Text(y.toString())))
                        .toList(),
                    onChanged: (v) => selectedYear = v!,
                  ),
                ),
              ),
              SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                    onTap: () => Navigator.pop(
                        context, DateTime(selectedYear, monthIndex, 1)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          months[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal')),
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

// Data Models
enum DayType { workDay, dayOff, holiday }

class AttendanceData {
  final DateTime date;
  final String checkinTime;
  final String checkoutTime;
  final String status;
  final DayType dayType;
  final String? timeoffName;
  final String? attendanceId; // Tambahkan ini
  final String? shift; // Tambahkan ini
  final bool isLateIn; // Tambahkan ini
  final bool isEarlyOut; // Tambahkan ini

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

  // Getters untuk UI
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
