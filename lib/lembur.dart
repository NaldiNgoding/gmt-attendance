// overtime_submission_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:image_picker/image_picker.dart';

// ============ MODEL ============
class AttendanceData {
  final String id;
  final String employeeid;
  final String nik;
  final String fullname;
  final DateTime date;
  final String shift;
  final String? schedulein;
  final String? scheduleout;
  final String? checkin;
  final String? checkout;
  final String? overtimecheckin;
  final String? overtimecheckout;
  final String status;
  final String attendancecode;

  AttendanceData({
    required this.id,
    required this.employeeid,
    required this.nik,
    required this.fullname,
    required this.date,
    required this.shift,
    this.schedulein,
    this.scheduleout,
    this.checkin,
    this.checkout,
    this.overtimecheckin,
    this.overtimecheckout,
    required this.status,
    required this.attendancecode,
  });

  factory AttendanceData.fromJson(Map<String, dynamic> json) {
    return AttendanceData(
      id: json['id'].toString(),
      employeeid: json['employeeid'] ?? '',
      nik: json['nik'] ?? '',
      fullname: json['fullname'] ?? '',
      date: DateTime.parse(json['date']),
      shift: json['shift'] ?? '',
      schedulein: json['schedulein'],
      scheduleout: json['scheduleout'],
      checkin: json['checkin'],
      checkout: json['checkout'],
      overtimecheckin: json['overtimecheckin'],
      overtimecheckout: json['overtimecheckout'],
      status: json['status'] ?? '',
      attendancecode: json['attendancecode'] ?? '',
    );
  }

  bool get hasCheckin => checkin != null && checkin!.isNotEmpty;
  bool get hasCheckout => checkout != null && checkout!.isNotEmpty;
}

class OvertimeHistory {
  final String id;
  final String status;
  final DateTime date;
  final String shift;
  final String? checkin;
  final String? checkout;
  final String? schedulein;
  final String? scheduleout;
  final String nama;
  final String reason;
  final String? namaApp1;
  final String? namaApp2;
  final String? namaApp3;
  final String? namaApp4;
  final String? approve1;
  final String? approve2;
  final String? approve3;
  final String? approve4;
  final String? approve1time;
  final String? approve2time;
  final String? approve3time;
  final String? approve4time;
  final String? rejecttime;

  OvertimeHistory({
    required this.id,
    required this.status,
    required this.date,
    required this.shift,
    this.checkin,
    this.checkout,
    this.schedulein,
    this.scheduleout,
    required this.nama,
    required this.reason,
    this.namaApp1,
    this.namaApp2,
    this.namaApp3,
    this.namaApp4,
    this.approve1,
    this.approve2,
    this.approve3,
    this.approve4,
    this.approve1time,
    this.approve2time,
    this.approve3time,
    this.approve4time,
    this.rejecttime,
  });

  factory OvertimeHistory.fromJson(Map<String, dynamic> json) {
    return OvertimeHistory(
      id: json['id'].toString(),
      status: json['status'] ?? 'Pending',
      date: DateTime.parse(json['date']),
      shift: json['shift'] ?? '',
      checkin: json['checkin'],
      checkout: json['checkout'],
      schedulein: json['schedulein'],
      scheduleout: json['scheduleout'],
      nama: json['nama'] ?? '',
      reason: json['reason'] ?? '',
      namaApp1: json['nama_app1'],
      namaApp2: json['nama_app2'],
      namaApp3: json['nama_app3'],
      namaApp4: json['nama_app4'],
      approve1: json['approve1'],
      approve2: json['approve2'],
      approve3: json['approve3'],
      approve4: json['approve4'],
      approve1time: json['approve1time'],
      approve2time: json['approve2time'],
      approve3time: json['approve3time'],
      approve4time: json['approve4time'],
      rejecttime: json['rejecttime'],
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'Pending':
        return 'Menunggu Approval';
      case 'Approved':
        return 'Disetujui';
      case 'Rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_empty_rounded;
      case 'Approved':
        return Icons.check_circle_rounded;
      case 'Rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

class OvertimeRequest {
  final String empid;
  final String attendanceid;
  final DateTime date;
  final String nama;
  final String nik;
  final String reason;
  final int ovtbefore_h;
  final int ovtbefore_m;
  final int brkbefore_h;
  final int brkbefore_m;
  final int ovtafter_h;
  final int ovtafter_m;
  final int brkafter_h;
  final int brkafter_m;
  final String status;
  final String statusby;
  final String createdby;
  final DateTime createddate;
  final String note;
  final String requesttime;
  final String expiredtime;

  OvertimeRequest({
    required this.empid,
    required this.attendanceid,
    required this.date,
    required this.nama,
    required this.nik,
    required this.reason,
    required this.ovtbefore_h,
    required this.ovtbefore_m,
    required this.brkbefore_h,
    required this.brkbefore_m,
    required this.ovtafter_h,
    required this.ovtafter_m,
    required this.brkafter_h,
    required this.brkafter_m,
    required this.status,
    required this.statusby,
    required this.createdby,
    required this.createddate,
    required this.note,
    required this.requesttime,
    required this.expiredtime,
  });

  Map<String, dynamic> toJson() {
    return {
      'empid': empid,
      'attendanceid': attendanceid,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'nama': nama,
      'nik': nik,
      'reason': reason,
      'ovtbefore_h': ovtbefore_h,
      'ovtbefore_m': ovtbefore_m,
      'brkbefore_h': brkbefore_h,
      'brkbefore_m': brkbefore_m,
      'ovtafter_h': ovtafter_h,
      'ovtafter_m': ovtafter_m,
      'brkafter_h': brkafter_h,
      'brkafter_m': brkafter_m,
      'status': status,
      'statusby': statusby,
      'createdby': createdby,
      'createddate': DateFormat('yyyy-MM-dd HH:mm:ss').format(createddate),
      'note': note,
      'requesttime': requesttime,
      'expiredtime': expiredtime,
      'isactive': '1',
    };
  }
}

// ============ SERVICE ============
class OvertimeService {
  static const String baseUrl = 'http://localhost:8000/api';

  Future<List<AttendanceData>> getAttendanceByEmployeeId(
      String empid, DateTime date) async {
    try {
      DateTime startOfMonth = DateTime(date.year, date.month, 1);
      DateTime endOfMonth = DateTime(date.year, date.month + 1, 0);

      final response = await http.get(
        Uri.parse('$baseUrl/getattendancebyemployeeid')
            .replace(queryParameters: {
          'id': empid,
          'start': DateFormat('yyyy-MM-dd').format(startOfMonth),
          'end': DateFormat('yyyy-MM-dd').format(endOfMonth),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          List<dynamic> data = jsonResponse['data'];
          return data.map((item) => AttendanceData.fromJson(item)).toList();
        } else {
          throw Exception(
              jsonResponse['message'] ?? 'Gagal mengambil data attendance');
        }
      } else {
        throw Exception('Gagal mengambil data attendance');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<List<OvertimeHistory>> getOvertimeHistory(
      String empid, int month, int year) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/getovertimebyempidbyperiod')
            .replace(queryParameters: {
          'id': empid,
          'month': month.toString(),
          'year': year.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          List<dynamic> data = jsonResponse['data'];
          return data.map((item) => OvertimeHistory.fromJson(item)).toList();
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      print('Error get overtime history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> submitOvertime(OvertimeRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/createovertime'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse;
      } else {
        throw Exception('Gagal submit lembur');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>> uploadOvertimeFile({
    required String overtimeId,
    required String empid,
    required String fileName,
    required String base64Data,
    required String ext,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/storeovtfile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'overtimeid': overtimeId,
          'empid': empid,
          'filename': fileName,
          'data': base64Data,
          'ext': ext,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse;
      } else {
        throw Exception('Gagal upload file');
      }
    } catch (e) {
      throw Exception('Error upload file: $e');
    }
  }
}

// ============ ENUM ============
enum OvertimeType {
  beforeWork,
  afterWork,
}

extension OvertimeTypeExtension on OvertimeType {
  String get displayName {
    switch (this) {
      case OvertimeType.beforeWork:
        return 'Sebelum Jam Kerja';
      case OvertimeType.afterWork:
        return 'Setelah Jam Kerja';
    }
  }
}

// ============ DESIGN TOKENS ============
class _AppColors {
  static const Color primary = Color(0xFF4F6EF7);
  static const Color primaryLight = Color(0xFFEEF1FF);
  static const Color accent = Color(0xFF7C3AED);
  static const Color surface = Color(0xFFF8F9FF);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color orange = Color(0xFFF97316);
  static const Color orangeLight = Color(0xFFFFF7ED);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleLight = Color(0xFFF5F3FF);
}

// ============ MAIN PAGE ============
class OvertimeSubmissionPage extends StatefulWidget {
  final String empid;
  final String nama;
  final String nik;

  const OvertimeSubmissionPage({
    Key? key,
    required this.empid,
    required this.nama,
    required this.nik,
  }) : super(key: key);

  @override
  State<OvertimeSubmissionPage> createState() => _OvertimeSubmissionPageState();
}

class _OvertimeSubmissionPageState extends State<OvertimeSubmissionPage>
    with TickerProviderStateMixin {
  final OvertimeService _service = OvertimeService();

  // State
  List<OvertimeHistory> _historyList = [];
  bool _isLoadingHistory = true;
  bool _showForm = false;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Form state
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  String _reason = '';
  List<AttendanceData> _attendanceList = [];
  AttendanceData? _selectedAttendance;
  bool _isLoadingAttendance = false;
  bool _isSubmitting = false;
  bool _isLocaleInitialized = false;
  OvertimeType? _selectedOvertimeType;

  // File upload
  final List<Map<String, String>> _selectedFiles = [];
  bool _isUploadingFile = false;
  static const int MAX_FILES = 3;

  // Controllers
  final TextEditingController _ovtBeforeHourController =
      TextEditingController();
  final TextEditingController _ovtBeforeMinuteController =
      TextEditingController();
  final TextEditingController _brkBeforeHourController =
      TextEditingController();
  final TextEditingController _brkBeforeMinuteController =
      TextEditingController();
  final TextEditingController _ovtAfterHourController = TextEditingController();
  final TextEditingController _ovtAfterMinuteController =
      TextEditingController();
  final TextEditingController _brkAfterHourController = TextEditingController();
  final TextEditingController _brkAfterMinuteController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _initializeLocale();
    _loadHistory();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _ovtBeforeHourController.dispose();
    _ovtBeforeMinuteController.dispose();
    _brkBeforeHourController.dispose();
    _brkBeforeMinuteController.dispose();
    _ovtAfterHourController.dispose();
    _ovtAfterMinuteController.dispose();
    _brkAfterHourController.dispose();
    _brkAfterMinuteController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('id_ID', null);
    setState(() {
      _isLocaleInitialized = true;
    });
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    final history = await _service.getOvertimeHistory(
        widget.empid, _selectedMonth, _selectedYear);

    setState(() {
      _historyList = history;
      _isLoadingHistory = false;
    });
  }

  Future<void> _changeMonth(int delta) async {
    int newMonth = _selectedMonth + delta;
    int newYear = _selectedYear;

    if (newMonth > 12) {
      newMonth = 1;
      newYear++;
    } else if (newMonth < 1) {
      newMonth = 12;
      newYear--;
    }

    setState(() {
      _selectedMonth = newMonth;
      _selectedYear = newYear;
    });

    await _loadHistory();
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoadingAttendance = true;
    });

    try {
      final attendanceList =
          await _service.getAttendanceByEmployeeId(widget.empid, _selectedDate);
      setState(() {
        _attendanceList = attendanceList;
        _selectedAttendance = attendanceList.firstWhere(
          (att) =>
              att.date.year == _selectedDate.year &&
              att.date.month == _selectedDate.month &&
              att.date.day == _selectedDate.day,
        );
      });

      if (_selectedAttendance == null) {
        _showSnackBar('Belum ada data absensi pada tanggal ini', isError: true);
      } else if (!_selectedAttendance!.hasCheckin ||
          !_selectedAttendance!.hasCheckout) {
        _showSnackBar('Belum melakukan checkin/checkout pada tanggal ini',
            isError: true);
      }
    } catch (e) {
      _showSnackBar('Gagal mengambil data absensi: $e', isError: true);
    } finally {
      setState(() {
        _isLoadingAttendance = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _AppColors.textPrimary,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedOvertimeType = null;
        _reason = '';
        _selectedFiles.clear();
        _ovtBeforeHourController.clear();
        _ovtBeforeMinuteController.clear();
        _brkBeforeHourController.clear();
        _brkBeforeMinuteController.clear();
        _ovtAfterHourController.clear();
        _ovtAfterMinuteController.clear();
        _brkAfterHourController.clear();
        _brkAfterMinuteController.clear();
        _noteController.clear();
      });
      await _loadAttendanceData();
    }
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '-';
    if (time.length >= 5) return time.substring(0, 5);
    return time;
  }

  void _resetOvertimeFields() {
    _ovtBeforeHourController.clear();
    _ovtBeforeMinuteController.clear();
    _brkBeforeHourController.clear();
    _brkBeforeMinuteController.clear();
    _ovtAfterHourController.clear();
    _ovtAfterMinuteController.clear();
    _brkAfterHourController.clear();
    _brkAfterMinuteController.clear();
  }

  Future<void> _pickImage() async {
    if (_selectedFiles.length >= MAX_FILES) {
      _showSnackBar('Maksimal upload $MAX_FILES gambar', isError: true);
      return;
    }

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() => _isUploadingFile = true);

        final File file = File(pickedFile.path);
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        final fileName = pickedFile.name;
        final ext = fileName.split('.').last.toLowerCase();

        if (ext != 'jpg' && ext != 'jpeg') {
          _showSnackBar('Hanya file JPG/JPEG yang diperbolehkan',
              isError: true);
          setState(() => _isUploadingFile = false);
          return;
        }

        setState(() {
          _selectedFiles.add({
            'fileName': fileName,
            'base64': base64String,
            'ext': ext,
          });
          _isUploadingFile = false;
        });
      }
    } catch (e) {
      setState(() => _isUploadingFile = false);
      _showSnackBar('Gagal memilih gambar: $e', isError: true);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _uploadFiles(String overtimeId) async {
    if (_selectedFiles.isEmpty) return;
    for (var file in _selectedFiles) {
      try {
        await _service.uploadOvertimeFile(
          overtimeId: overtimeId,
          empid: widget.empid,
          fileName: file['fileName']!,
          base64Data: file['base64']!,
          ext: file['ext']!,
        );
      } catch (e) {
        print('Error uploading file: $e');
      }
    }
  }

  Future<void> _submitOvertime() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedAttendance == null) {
        _showSnackBar('Tidak ada data absensi untuk tanggal yang dipilih',
            isError: true);
        return;
      }
      if (!_selectedAttendance!.hasCheckin ||
          !_selectedAttendance!.hasCheckout) {
        _showSnackBar(
            'Harus melakukan checkin dan checkout untuk mengajukan lembur',
            isError: true);
        return;
      }
      if (_selectedOvertimeType == null) {
        _showSnackBar('Silakan pilih jenis lembur terlebih dahulu',
            isError: true);
        return;
      }
      if (_reason.isEmpty) {
        _showSnackBar('Alasan lembur harus diisi', isError: true);
        return;
      }

      int ovtBeforeTotal = 0, ovtAfterTotal = 0;
      if (_selectedOvertimeType == OvertimeType.beforeWork) {
        ovtBeforeTotal =
            (int.tryParse(_ovtBeforeHourController.text) ?? 0) * 60 +
                (int.tryParse(_ovtBeforeMinuteController.text) ?? 0);
        if (ovtBeforeTotal == 0) {
          _showSnackBar('Durasi lembur sebelum jam kerja harus diisi',
              isError: true);
          return;
        }
      } else {
        ovtAfterTotal = (int.tryParse(_ovtAfterHourController.text) ?? 0) * 60 +
            (int.tryParse(_ovtAfterMinuteController.text) ?? 0);
        if (ovtAfterTotal == 0) {
          _showSnackBar('Durasi lembur setelah jam kerja harus diisi',
              isError: true);
          return;
        }
      }

      setState(() => _isSubmitting = true);

      DateTime now = DateTime.now();
      String requesttime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      String expiredtime = DateFormat('yyyy-MM-dd HH:mm:ss')
          .format(now.add(const Duration(days: 7)));

      final request = OvertimeRequest(
        empid: widget.empid,
        attendanceid: _selectedAttendance!.id,
        date: _selectedDate,
        nama: widget.nama,
        nik: widget.nik,
        reason: _reason,
        ovtbefore_h: int.tryParse(_ovtBeforeHourController.text) ?? 0,
        ovtbefore_m: int.tryParse(_ovtBeforeMinuteController.text) ?? 0,
        brkbefore_h: int.tryParse(_brkBeforeHourController.text) ?? 0,
        brkbefore_m: int.tryParse(_brkBeforeMinuteController.text) ?? 0,
        ovtafter_h: int.tryParse(_ovtAfterHourController.text) ?? 0,
        ovtafter_m: int.tryParse(_ovtAfterMinuteController.text) ?? 0,
        brkafter_h: int.tryParse(_brkAfterHourController.text) ?? 0,
        brkafter_m: int.tryParse(_brkAfterMinuteController.text) ?? 0,
        status: 'Pending',
        statusby: '',
        createdby: widget.empid,
        createddate: DateTime.now(),
        note: _noteController.text,
        requesttime: requesttime,
        expiredtime: expiredtime,
      );

      try {
        final result = await _service.submitOvertime(request);
        if (result['success'] == true) {
          final overtimeId = result['data']?.toString();
          if (_selectedFiles.isNotEmpty && overtimeId != null) {
            await _uploadFiles(overtimeId);
          }
          _showSnackBar('Pengajuan lembur berhasil dikirim');
          setState(() {
            _showForm = false;
            _selectedFiles.clear();
            _resetOvertimeFields();
            _reason = '';
            _noteController.clear();
            _selectedOvertimeType = null;
          });
          await _loadHistory();
        } else {
          _showSnackBar(result['message'] ?? 'Gagal mengirim pengajuan',
              isError: true);
        }
      } catch (e) {
        _showSnackBar('Error: $e', isError: true);
      } finally {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? _AppColors.error : _AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'Pending':
        return 'Menunggu Approval';
      case 'Approved':
        return 'Disetujui';
      case 'Rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ============ BUILD ============
  @override
  Widget build(BuildContext context) {
    if (!_isLocaleInitialized) {
      return Scaffold(
        backgroundColor: _AppColors.surface,
        body: const Center(
            child: CircularProgressIndicator(color: _AppColors.primary)),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _AppColors.surface,
        appBar: AppBar(
          title: const Text('Riwayat Lembur'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: _AppColors.textPrimary,
          centerTitle: true,
          actions: [
            if (!_showForm)
              IconButton(
                onPressed: () {
                  setState(() {
                    _showForm = true;
                    _loadAttendanceData();
                  });
                },
                icon: const Icon(Icons.add_rounded, color: _AppColors.primary),
                tooltip: 'Ajukan Lembur',
              ),
          ],
        ),
        body: _showForm ? _buildFormView() : _buildHistoryView(),
      ),
    );
  }

  Widget _buildHistoryView() {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Background Watermark
        Positioned.fill(
          child: Opacity(
            opacity: 0.2, // Transparansi watermark
            child: Image.asset(
              'assets/images/GMT3.png',
              width: screenSize.width * 0.25,
              height: screenSize.width * 0.25,
            ),
          ),
        ),
        // Content
        Column(
          children: [
            // Month selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text(
                    '${DateFormat('MMMM', 'id_ID').format(DateTime(_selectedYear, _selectedMonth))} $_selectedYear',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _historyList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_rounded,
                                  size: 64, color: const Color.fromARGB(255, 0, 0, 0)),
                              const SizedBox(height: 16),
                              Text('Belum ada riwayat lembur',
                                  style: TextStyle(color: const Color.fromARGB(255, 0, 0, 0))),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showForm = true;
                                    _loadAttendanceData();
                                  });
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Ajukan Lembur'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _historyList.length,
                          itemBuilder: (context, index) {
                            final item = _historyList[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: _AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ExpansionTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(item.status)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.statusIcon,
                                    color: _getStatusColor(item.status),
                                    size: 24,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        DateFormat('dd MMMM yyyy', 'id_ID')
                                            .format(item.date),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(item.status)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStatusText(item.status),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _getStatusColor(item.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(item.reason,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildInfoRow(
                                            'Tanggal',
                                            DateFormat('EEEE, d MMMM yyyy',
                                                    'id_ID')
                                                .format(item.date)),
                                        const SizedBox(height: 8),
                                        _buildInfoRow('Shift', item.shift),
                                        const SizedBox(height: 8),
                                        _buildInfoRow('Jam Kerja',
                                            '${_formatTime(item.schedulein)} - ${_formatTime(item.scheduleout)}'),
                                        const SizedBox(height: 8),
                                        _buildInfoRow('Check In/Out',
                                            '${_formatTime(item.checkin)} / ${_formatTime(item.checkout)}'),
                                        const SizedBox(height: 8),
                                        _buildInfoRow('Alasan', item.reason),
                                        if (item.status == 'Approved') ...[
                                          const SizedBox(height: 8),
                                          const Divider(),
                                          const SizedBox(height: 8),
                                          _buildApprovalStatus(item),
                                        ],
                                      ],
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
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: _AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildApprovalStatus(OvertimeHistory item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Approval Status',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (item.namaApp1 != null)
          _buildApprovalRow(
              'Approval 1', item.namaApp1!, item.approve1, item.approve1time),
        if (item.namaApp2 != null)
          _buildApprovalRow(
              'Approval 2', item.namaApp2!, item.approve2, item.approve2time),
        if (item.namaApp3 != null)
          _buildApprovalRow(
              'Approval 3', item.namaApp3!, item.approve3, item.approve3time),
        if (item.namaApp4 != null)
          _buildApprovalRow(
              'Approval 4', item.namaApp4!, item.approve4, item.approve4time),
        if (item.rejecttime != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Ditolak pada: ${_formatDateTime(item.rejecttime)}',
                style: const TextStyle(fontSize: 11, color: _AppColors.error)),
          ),
      ],
    );
  }

  Widget _buildApprovalRow(
      String level, String nama, String? status, String? time) {
    Color statusColor =
        status == 'Approved' ? _AppColors.success : _AppColors.warning;
    String statusText = status == 'Approved' ? '✓ Disetujui' : '⏳ Menunggu';
    if (status == 'Approved' && time != null) {
      statusText = '✓ Disetujui ${_formatDateTime(time)}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text('$level:', style: const TextStyle(fontSize: 11))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nama,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500)),
                Text(statusText,
                    style: TextStyle(fontSize: 10, color: statusColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return '';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(dateTime));
    } catch (e) {
      return dateTime;
    }
  }

  // ============ FORM VIEW (Sama seperti sebelumnya) ============
  Widget _buildFormView() {
    return Scaffold(
      backgroundColor: _AppColors.surface,
      appBar: AppBar(
        title: const Text('Ajukan Lembur'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _AppColors.textPrimary,
        leading: IconButton(
          onPressed: () {
            setState(() {
              _showForm = false;
              _selectedFiles.clear();
              _resetOvertimeFields();
              _reason = '';
              _noteController.clear();
              _selectedOvertimeType = null;
            });
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateSelector(),
              const SizedBox(height: 16),
              _buildAttendanceStatus(),
              const SizedBox(height: 16),
              _buildOvertimeTypeSelector(),
              const SizedBox(height: 16),
              if (_selectedOvertimeType == OvertimeType.beforeWork)
                _buildOvertimeDurationCard(
                  type: OvertimeType.beforeWork,
                  durationHourController: _ovtBeforeHourController,
                  durationMinuteController: _ovtBeforeMinuteController,
                  breakHourController: _brkBeforeHourController,
                  breakMinuteController: _brkBeforeMinuteController,
                ),
              if (_selectedOvertimeType == OvertimeType.afterWork)
                _buildOvertimeDurationCard(
                  type: OvertimeType.afterWork,
                  durationHourController: _ovtAfterHourController,
                  durationMinuteController: _ovtAfterMinuteController,
                  breakHourController: _brkAfterHourController,
                  breakMinuteController: _brkAfterMinuteController,
                ),
              if (_selectedOvertimeType != null) ...[
                const SizedBox(height: 16),
                _buildReasonField(),
                const SizedBox(height: 16),
                _buildFileUploadSection(),
                const SizedBox(height: 16),
                _buildNoteField(),
              ],
              const SizedBox(height: 28),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('BUKTI LEMBUR (MAKS 3 GAMBAR)'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _AppColors.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              if (_selectedFiles.length < MAX_FILES)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: _selectedFiles.isNotEmpty
                              ? BorderSide(color: _AppColors.divider)
                              : BorderSide.none),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_upload_rounded,
                            size: 40, color: _AppColors.primary),
                        const SizedBox(height: 8),
                        Text('Upload Gambar',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _AppColors.primary)),
                        const SizedBox(height: 4),
                        Text('Format JPG/JPEG | Maks 3 gambar',
                            style: TextStyle(
                                fontSize: 11, color: _AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              if (_isUploadingFile)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                ),
              if (_selectedFiles.isNotEmpty)
                ..._selectedFiles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return Dismissible(
                    key: Key(file['fileName']!),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                          color: _AppColors.error,
                          borderRadius: BorderRadius.circular(12)),
                      child:
                          const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    onDismissed: (_) => _removeFile(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: _AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.image_outlined,
                                size: 20, color: _AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Gambar ${index + 1}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                Text(file['fileName']!,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _AppColors.textMuted),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeFile(index),
                            icon: Icon(Icons.close_rounded,
                                size: 20, color: _AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _AppColors.textSecondary,
              letterSpacing: 0.8)),
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('TANGGAL LEMBUR'),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _AppColors.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: _AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: _AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                              .format(_selectedDate),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                          DateFormat('MMMM yyyy', 'id_ID')
                              .format(_selectedDate),
                          style: const TextStyle(
                              fontSize: 12, color: _AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: _AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('Ubah',
                      style: TextStyle(
                          fontSize: 12,
                          color: _AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceStatus() {
    if (_isLoadingAttendance) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: _AppColors.card, borderRadius: BorderRadius.circular(16)),
        child: const Center(
            child: SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(
                    color: _AppColors.primary, strokeWidth: 2.5))),
      );
    }
    if (_selectedAttendance == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _AppColors.warningLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _AppColors.warning.withOpacity(0.3))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.info_outline_rounded,
                  color: _AppColors.warning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  'Tidak ada data absensi untuk tanggal ${DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate)}',
                  style: const TextStyle(
                      color: _AppColors.warning,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
    }
    final bool isComplete =
        _selectedAttendance!.hasCheckin && _selectedAttendance!.hasCheckout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('STATUS ABSENSI'),
        Container(
          decoration: BoxDecoration(
              color: _AppColors.card, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: isComplete
                      ? _AppColors.successLight
                      : _AppColors.errorLight,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(
                        isComplete
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color:
                            isComplete ? _AppColors.success : _AppColors.error,
                        size: 18),
                    const SizedBox(width: 8),
                    Text(
                        isComplete
                            ? 'Absensi lengkap'
                            : 'Absensi belum lengkap',
                        style: TextStyle(
                            color: isComplete
                                ? _AppColors.success
                                : _AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                        child: _buildTimeBox(
                            label: 'Check In',
                            time: _formatTime(_selectedAttendance!.checkin),
                            hasData: _selectedAttendance!.hasCheckin)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildTimeBox(
                            label: 'Check Out',
                            time: _formatTime(_selectedAttendance!.checkout),
                            hasData: _selectedAttendance!.hasCheckout)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildTimeBox(
                            label: 'Shift',
                            time: _selectedAttendance!.shift.isNotEmpty
                                ? _selectedAttendance!.shift
                                : '-',
                            hasData: _selectedAttendance!.shift.isNotEmpty,
                            isNeutral: true)),
                  ],
                ),
              ),
              if (_selectedAttendance!.shift.isNotEmpty) ...[
                Divider(height: 1, color: _AppColors.divider),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildScheduleChip('Masuk',
                          _formatTime(_selectedAttendance!.schedulein)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 14, color: _AppColors.textMuted),
                      const SizedBox(width: 8),
                      _buildScheduleChip('Pulang',
                          _formatTime(_selectedAttendance!.scheduleout)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeBox(
      {required String label,
      required String time,
      required bool hasData,
      bool isNeutral = false}) {
    Color textColor = isNeutral
        ? _AppColors.primary
        : (hasData ? _AppColors.success : _AppColors.error);
    Color bgColor = isNeutral
        ? _AppColors.primaryLight
        : (hasData ? _AppColors.successLight : _AppColors.errorLight);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: _AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(time,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildScheduleChip(String label, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: _AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _AppColors.divider)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: _AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Text(time,
              style: const TextStyle(
                  fontSize: 12,
                  color: _AppColors.textPrimary,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildOvertimeTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('PILIH JENIS LEMBUR'),
        Row(
          children: [
            Expanded(
              child: _buildOvertimeTypeCard(
                type: OvertimeType.beforeWork,
                icon: '⏰',
                title: 'Sebelum Kerja',
                subtitle: 'Lembur sebelum\njam masuk',
                isSelected: _selectedOvertimeType == OvertimeType.beforeWork,
                color: _AppColors.orange,
                bgColor: _AppColors.orangeLight,
                onTap: () {
                  setState(() {
                    if (_selectedOvertimeType == OvertimeType.beforeWork) {
                      _selectedOvertimeType = null;
                      _resetOvertimeFields();
                    } else {
                      _selectedOvertimeType = OvertimeType.beforeWork;
                      _resetOvertimeFields();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildOvertimeTypeCard(
                type: OvertimeType.afterWork,
                icon: '🌙',
                title: 'Setelah Kerja',
                subtitle: 'Lembur setelah\njam pulang',
                isSelected: _selectedOvertimeType == OvertimeType.afterWork,
                color: _AppColors.purple,
                bgColor: _AppColors.purpleLight,
                onTap: () {
                  setState(() {
                    if (_selectedOvertimeType == OvertimeType.afterWork) {
                      _selectedOvertimeType = null;
                      _resetOvertimeFields();
                    } else {
                      _selectedOvertimeType = OvertimeType.afterWork;
                      _resetOvertimeFields();
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOvertimeTypeCard({
    required OvertimeType type,
    required String icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : _AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? color : _AppColors.divider,
              width: isSelected ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: isSelected
                    ? color.withOpacity(0.15)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isSelected ? 12 : 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.15) : bgColor,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 20))),
                ),
                if (isSelected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : _AppColors.textPrimary)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11,
                    color: _AppColors.textSecondary,
                    height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildOvertimeDurationCard({
    required OvertimeType type,
    required TextEditingController durationHourController,
    required TextEditingController durationMinuteController,
    required TextEditingController breakHourController,
    required TextEditingController breakMinuteController,
  }) {
    final bool isBefore = type == OvertimeType.beforeWork;
    final Color accentColor = isBefore ? _AppColors.orange : _AppColors.purple;
    final Color accentBg =
        isBefore ? _AppColors.orangeLight : _AppColors.purpleLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('DURASI LEMBUR'),
        Container(
          decoration: BoxDecoration(
              color: _AppColors.card, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(
                  children: [
                    Text(isBefore ? '⏰' : '🌙',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(
                        isBefore
                            ? 'Lembur Sebelum Jam Kerja'
                            : 'Lembur Setelah Jam Kerja',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: accentColor)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDurationRow(
                      label: 'Lembur',
                      icon: Icons.timer_outlined,
                      hourController: durationHourController,
                      minuteController: durationMinuteController,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: _AppColors.divider),
                    const SizedBox(height: 16),
                    _buildDurationRow(
                      label: 'Istirahat',
                      icon: Icons.coffee_outlined,
                      hourController: breakHourController,
                      minuteController: breakMinuteController,
                      accentColor: accentColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationRow({
    required String label,
    required IconData icon,
    required TextEditingController hourController,
    required TextEditingController minuteController,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: accentColor, size: 18),
        const SizedBox(width: 8),
        SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _AppColors.textPrimary))),
        Expanded(
            child: _buildTimeInput(
                controller: hourController,
                suffix: 'jam',
                max: 23,
                accentColor: accentColor)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildTimeInput(
                controller: minuteController,
                suffix: 'mnt',
                max: 59,
                accentColor: accentColor)),
      ],
    );
  }

  Widget _buildTimeInput({
    required TextEditingController controller,
    required String suffix,
    required int max,
    required Color accentColor,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2)
      ],
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: const TextStyle(
            color: _AppColors.textMuted,
            fontWeight: FontWeight.w400,
            fontSize: 14),
        suffixText: suffix,
        suffixStyle: const TextStyle(
            fontSize: 11,
            color: _AppColors.textSecondary,
            fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _AppColors.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accentColor, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _AppColors.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _AppColors.error, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        filled: true,
        fillColor: _AppColors.surface,
        errorStyle: const TextStyle(fontSize: 9, height: 0.8),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final intVal = int.tryParse(value);
          if (intVal != null && (intVal < 0 || intVal > max)) return '0–$max';
        }
        return null;
      },
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('ALASAN LEMBUR'),
        Container(
          decoration: BoxDecoration(
              color: _AppColors.card, borderRadius: BorderRadius.circular(16)),
          child: TextFormField(
            maxLines: 3,
            style: const TextStyle(fontSize: 14, color: _AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Jelaskan alasan lembur Anda...',
              hintStyle:
                  const TextStyle(color: _AppColors.textMuted, fontSize: 14),
              prefixIcon: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 0, 0),
                child: Icon(Icons.edit_note_rounded,
                    color: _AppColors.textMuted, size: 22),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: _AppColors.primary, width: 1.5)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: _AppColors.error, width: 1.5)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: _AppColors.error, width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: _AppColors.card,
            ),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Alasan lembur harus diisi'
                : null,
            onChanged: (value) => _reason = value,
          ),
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('CATATAN (OPSIONAL)'),
        Container(
          decoration: BoxDecoration(
              color: _AppColors.card, borderRadius: BorderRadius.circular(16)),
          child: TextFormField(
            controller: _noteController,
            maxLines: 2,
            style: const TextStyle(fontSize: 14, color: _AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Tambahkan catatan jika diperlukan...',
              hintStyle:
                  const TextStyle(color: _AppColors.textMuted, fontSize: 14),
              prefixIcon: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 0, 0),
                child: Icon(Icons.sticky_note_2_outlined,
                    color: _AppColors.textMuted, size: 20),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: _AppColors.primary, width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: _AppColors.card,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final bool canSubmit = !_isSubmitting &&
        _selectedAttendance != null &&
        _selectedAttendance!.hasCheckin &&
        _selectedAttendance!.hasCheckout &&
        _selectedOvertimeType != null &&
        _reason.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: canSubmit
            ? const LinearGradient(
                colors: [_AppColors.primary, _AppColors.accent],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight)
            : null,
        color: canSubmit ? null : _AppColors.divider,
        borderRadius: BorderRadius.circular(16),
        boxShadow: canSubmit
            ? [
                BoxShadow(
                    color: _AppColors.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSubmit ? _submitOvertime : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_rounded,
                          color:
                              canSubmit ? Colors.white : _AppColors.textMuted,
                          size: 18),
                      const SizedBox(width: 10),
                      Text('Ajukan Lembur',
                          style: TextStyle(
                              color: canSubmit
                                  ? Colors.white
                                  : _AppColors.textMuted,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
