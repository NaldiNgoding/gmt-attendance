import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// PAGE
// ============================================================

class TimeOffPage extends StatefulWidget {
  const TimeOffPage({super.key});

  @override
  State<TimeOffPage> createState() => _TimeOffPageState();
}

class _TimeOffPageState extends State<TimeOffPage> {
  // ============================================================
  // CONSTANTS
  // ============================================================

  static const String baseUrl = 'http://192.168.0.151:8000/api';

  static const Color kNavy = Color(0xFF0D47A1);
  static const Color kBackground = Color(0xFFF6F8FC);
  static const Color kFieldBg = Color(0xFFF8FAFD);
  static const Color kTextPrimary = Color(0xFF252525);

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _monthsShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  // ============================================================
  // STATE — User
  // ============================================================

  String _employeeId = '';

  // ============================================================
  // STATE — Leave Balance
  // ============================================================

  double _remainingBalance = 0;
  int _balanceYear = DateTime.now().year;
  bool _isLoadingBalance = true;
  String? _balanceError;

  // ============================================================
  // STATE — History
  // ============================================================

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<Map<String, dynamic>> _historyList = [];
  bool _isLoadingHistory = false;
  String? _historyError;

  // ============================================================
  // STATE — Time-Off Form
  // ============================================================

  Map<String, dynamic>? _selectedTimeOffType;
  List<Map<String, dynamic>> _timeOffTypes = [];
  bool _isLoadingTimeOffTypes = false;
  String? _timeOffTypeError;

  DateTime? _requestStartDate;
  DateTime? _requestEndDate;

  final TextEditingController _reasonController = TextEditingController();

  List<PlatformFile?> _selectedAttachments =
      List<PlatformFile?>.filled(3, null);

  bool _isSubmittingTimeOff = false;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    await _loadLeaveBalance();
    await Future.wait([
      _loadHistory(),
      _loadTimeOffTypes(),
    ]);
  }

  // ============================================================
  // PARSING HELPERS
  // ============================================================

  /// Parse `data` menjadi List<Map>. Mendukung List, Map tunggal,
  /// Map nested (`data`/`items`), dan menyaring item kosong.
  List<Map<String, dynamic>> _parseDataList(dynamic raw) {
    if (raw == null) return [];

    List<Map<String, dynamic>> result = [];

    if (raw is List) {
      result = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else if (raw is Map) {
      if (raw['data'] is List) {
        result = (raw['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (raw['items'] is List) {
        result = (raw['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        result = [Map<String, dynamic>.from(raw)];
      }
    }

    // Buang Map kosong
    result = result.where((e) => e.isNotEmpty).toList();

    // ✅ Filter: hanya pertahankan item yang punya info untuk ditampilkan
    result = result.where((item) {
      final name = item['timeoff_name']?.toString().trim() ?? '';
      final start = item['date_start']?.toString().trim() ?? '';
      final end = item['date_end']?.toString().trim() ?? '';

      final hasName = name.isNotEmpty && name != '-' && name != '--';
      final hasDate = (start.isNotEmpty && start != '-' && start != '--') ||
          (end.isNotEmpty && end != '-' && end != '--');

      return hasName || hasDate;
    }).toList();

    return result;
  }

  Map<String, dynamic>? _parseDataMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      if (raw['data'] is Map) {
        return Map<String, dynamic>.from(raw['data'] as Map);
      }
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  // ============================================================
  // API — LEAVE BALANCE
  // ============================================================

  Future<void> _loadLeaveBalance() async {
    if (!mounted) return;

    setState(() {
      _isLoadingBalance = true;
      _balanceError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getString('empid') ?? '';

      if (employeeId.isEmpty) {
        throw Exception('Employee ID tidak ditemukan.');
      }

      final uri = Uri.parse('$baseUrl/my-leave-balance').replace(
        queryParameters: {'employeeid': employeeId},
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded['success'] != true) {
        throw Exception(decoded['message'] ?? 'Gagal mengambil saldo cuti.');
      }

      final data = _parseDataMap(decoded['data']) ?? {};
      final remaining = double.tryParse(
            data['remaining_balance']?.toString() ?? '0',
          ) ??
          0;

      if (!mounted) return;

      setState(() {
        _employeeId = employeeId;
        _balanceYear =
            int.tryParse(data['year']?.toString() ?? '') ?? DateTime.now().year;
        _remainingBalance = remaining;
        _isLoadingBalance = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBalance = false;
        _balanceError = e.toString();
      });
    }
  }

  // ============================================================
  // API — HISTORY
  // ============================================================

  Future<void> _loadHistory() async {
    if (_employeeId.isEmpty) return;

    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/my-timeoff-history').replace(
        queryParameters: {
          'employeeid': _employeeId,
          'month': _selectedMonth.toString(),
          'year': _selectedYear.toString(),
        },
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      if (json['success'] != true) {
        throw Exception(
            json['message']?.toString() ?? 'Gagal mengambil riwayat');
      }

      final parsed = _parseDataList(json['data']);

      if (!mounted) return;
      setState(() {
        _historyList = parsed;
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString();
        _isLoadingHistory = false;
        _historyList = [];
      });
    }
  }

  // ============================================================
  // API — TIME-OFF TYPES
  // ============================================================

  Future<void> _loadTimeOffTypes() async {
    if (!mounted) return;

    setState(() {
      _isLoadingTimeOffTypes = true;
      _timeOffTypeError = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/timeoff-types');

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded['success'] != true) {
        throw Exception(
          decoded['message']?.toString() ?? 'Gagal mengambil jenis time-off.',
        );
      }

      final parsed = _parseDataList(decoded['data']);

      if (!mounted) return;
      setState(() {
        _timeOffTypes = parsed;
        _isLoadingTimeOffTypes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _timeOffTypes = [];
        _isLoadingTimeOffTypes = false;
        _timeOffTypeError = e.toString();
      });
    }
  }

  // ============================================================
  // API — SUBMIT TIME-OFF
  // ============================================================

  Future<void> _submitTimeOff(StateSetter setSheetState) async {
    if (!_validateForm()) return;

    final now = DateTime.now();
    final startDate = _requestStartDate!;
    final endDate = _requestEndDate!;
    final expiredDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    );

    setSheetState(() => _isSubmittingTimeOff = true);

    try {
      final body = {
        'empid': _employeeId,
        'timeoffid': _selectedTimeOffType!['id'],
        'datestart': _formatApiDate(startDate),
        'dateend': _formatApiDate(endDate),
        'intime': null,
        'outtime': null,
        'reason': _reasonController.text.trim(),
        'createdby': null,
        'createddate': _formatApiDate(now),
        'requesttime': _formatApiDateTime(now),
        'expiredtime': _formatApiDateTime(expiredDate),
        'attachment1': await _encodeAttachment(_selectedAttachments[0]),
        'attachment2': await _encodeAttachment(_selectedAttachments[1]),
        'attachment3': await _encodeAttachment(_selectedAttachments[2]),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/createtimeoffdata'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['success'] == true) {
        if (mounted) Navigator.of(context).pop();
        _resetForm();

        await Future.wait([
          _loadLeaveBalance(),
          _loadHistory(),
        ]);

        _snack('Pengajuan Time-Off berhasil dikirim.');
      } else {
        throw Exception(
            responseData['message'] ?? 'Gagal mengajukan Time-Off.');
      }
    } catch (e) {
      setSheetState(() => _isSubmittingTimeOff = false);
      _snack('Gagal mengajukan Time-Off: $e');
    }
  }

  bool _validateForm() {
    if (_selectedTimeOffType == null) {
      _snack('Silakan pilih jenis time-off.');
      return false;
    }
    if (_requestStartDate == null || _requestEndDate == null) {
      _snack('Silakan pilih tanggal time-off.');
      return false;
    }
    if (_reasonController.text.trim().isEmpty) {
      _snack('Silakan isi alasan pengajuan.');
      return false;
    }
    return true;
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  String _formatApiDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  String _formatApiDateTime(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final mi = date.minute.toString().padLeft(2, '0');
    final s = date.second.toString().padLeft(2, '0');
    return '${date.year}-$m-$d $h:$mi:$s';
  }

  String _formatRequestDate(DateTime date) {
    return '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';
  }

  Future<String?> _encodeAttachment(PlatformFile? file) async {
    if (file == null) return null;
    if (file.bytes != null) return base64Encode(file.bytes!);
    if (file.path != null) {
      final bytes = await File(file.path!).readAsBytes();
      return base64Encode(bytes);
    }
    return null;
  }

  String _formatBalance() {
    if (_remainingBalance == _remainingBalance.truncateToDouble()) {
      return _remainingBalance.toInt().toString();
    }
    return _remainingBalance.toStringAsFixed(1);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetForm() {
    if (!mounted) return;
    _reasonController.clear();
    setState(() {
      _selectedTimeOffType = null;
      _requestStartDate = null;
      _requestEndDate = null;
      _selectedAttachments = List<PlatformFile?>.filled(3, null);
      _isSubmittingTimeOff = false;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cuti Karyawan/ti Tahunan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kNavy,
              ),
            ),
            const SizedBox(height: 16),
            _buildLeaveBalanceSection(),
            const SizedBox(height: 24),
            _buildHistoryHeader(),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMonthDropdown(),
                const SizedBox(width: 10),
                _buildYearDropdown(),
              ],
            ),
            const SizedBox(height: 16),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Time Off',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  // ============================================================
  // LEAVE BALANCE SECTION
  // ============================================================

  Widget _buildLeaveBalanceSection() {
    if (_isLoadingBalance) {
      return Container(
        width: double.infinity,
        height: 145,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(child: CircularProgressIndicator(color: kNavy)),
      );
    }

    if (_balanceError != null) {
      return _buildErrorCard(
        title: 'Gagal mengambil saldo cuti',
        onRetry: _loadLeaveBalance,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kNavy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(CupertinoIcons.calendar, color: kNavy, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sisa Jatah Cuti',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatBalance()} Hari',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: kNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tahun $_balanceYear',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard({
    required String title,
    required VoidCallback onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: Colors.red.shade400,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY HEADER + DROPDOWN
  // ============================================================

  Widget _buildHistoryHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Riwayat Pengajuan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: kNavy,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _showRequestSheet,
          icon: const Icon(CupertinoIcons.add, size: 16),
          label: const Text(
            'Ajukan',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthDropdown() {
    return _buildDropdownContainer(
      child: DropdownButton<int>(
        value: _selectedMonth,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        items: List.generate(12, (i) {
          return DropdownMenuItem<int>(
            value: i + 1,
            child: Text(
              _months[i],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          );
        }),
        onChanged: (v) async {
          if (v == null || v == _selectedMonth) return;
          setState(() => _selectedMonth = v);
          await _loadHistory();
        },
      ),
    );
  }

  Widget _buildYearDropdown() {
    final currentYear = DateTime.now().year;
    return _buildDropdownContainer(
      child: DropdownButton<int>(
        value: _selectedYear,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        items: List.generate(5, (i) {
          final y = currentYear - i;
          return DropdownMenuItem<int>(
            value: y,
            child: Text(
              y.toString(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          );
        }),
        onChanged: (v) async {
          if (v == null || v == _selectedYear) return;
          setState(() => _selectedYear = v);
          await _loadHistory();
        },
      ),
    );
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Expanded(
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: DropdownButtonHideUnderline(child: child),
      ),
    );
  }

  // ============================================================
  // HISTORY SECTION
  // ============================================================

  Widget _buildHistorySection() {
    if (_isLoadingHistory) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: const Center(child: CircularProgressIndicator(color: kNavy)),
      );
    }

    if (_historyError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            _historyError!,
            style: TextStyle(fontSize: 13, color: Colors.red.shade400),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_historyList.isEmpty) {
      return _buildEmptyHistory();
    }

    return Column(
      children: _historyList.map(_buildHistoryItem).toList(),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kNavy.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.calendar,
              size: 30,
              color: kNavy.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Belum Ada Riwayat',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pengajuan time-off Anda akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? '-';
    final rejectNote = item['reject_note']?.toString() ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['timeoff_name']?.toString() ?? '-',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${item['date_start'] ?? '-'} - ${item['date_end'] ?? '-'}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          _buildStatusBadge(status),
          if (status.trim().toLowerCase() == 'rejected' &&
              rejectNote.trim().isNotEmpty)
            _buildRejectNote(rejectNote),
        ],
      ),
    );
  }

  Widget _buildRejectNote(String note) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reject Note',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            note,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final normalized = status.trim().toLowerCase();

    Color bg;
    Color fg;

    switch (normalized) {
      case 'approved':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'rejected':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        break;
      case 'pending':
        bg = Colors.yellow.shade50;
        fg = Colors.yellow.shade700;
        break;
      default:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        status.isEmpty ? '-' : status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  // ============================================================
  // REQUEST SHEET
  // ============================================================

  void _showRequestSheet() {
    _resetForm();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return _buildRequestSheet(sheetContext, setSheetState);
          },
        );
      },
    );
  }

  Widget _buildRequestSheet(
    BuildContext sheetContext,
    StateSetter setSheetState,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              _buildSheetHandle(),
              _buildSheetHeader(sheetContext),
              Divider(height: 1, color: Colors.grey.shade200),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  children: [_buildRequestForm(setSheetState)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSheetHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildSheetHeader(BuildContext sheetContext) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kNavy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              CupertinoIcons.calendar_badge_plus,
              color: kNavy,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request Time-Off',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kNavy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ajukan cuti atau time-off',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(sheetContext),
            splashRadius: 20,
            icon: const Icon(
              CupertinoIcons.xmark,
              size: 19,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm(StateSetter setSheetState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormLabel('Time-Off Type'),
        const SizedBox(height: 7),
        _buildTimeOffTypeField(setSheetState),
        const SizedBox(height: 16),
        _buildFormLabel('Tanggal'),
        const SizedBox(height: 7),
        _buildRequestDateField(setSheetState),
        const SizedBox(height: 16),
        _buildFormLabel('Reason'),
        const SizedBox(height: 7),
        _buildReasonField(),
        const SizedBox(height: 18),
        _buildFormLabel('Attachment'),
        const SizedBox(height: 4),
        Text(
          'Maksimal 3 file • Maksimal 10 MB per file',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        _buildAttachmentSection(setSheetState),
        const SizedBox(height: 24),
        _buildSubmitButton(setSheetState),
      ],
    );
  }

  Widget _buildFormLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: kTextPrimary,
      ),
    );
  }

  Widget _buildSubmitButton(StateSetter setSheetState) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed:
            _isSubmittingTimeOff ? null : () => _submitTimeOff(setSheetState),
        style: ElevatedButton.styleFrom(
          backgroundColor: kNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: _isSubmittingTimeOff
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Submit Request',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  // ============================================================
  // FORM FIELDS
  // ============================================================

  Widget _buildTimeOffTypeField(StateSetter setSheetState) {
    if (_isLoadingTimeOffTypes) {
      return _fieldWrapper(
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: kNavy),
          ),
        ),
      );
    }

    if (_timeOffTypeError != null) {
      return _fieldWrapper(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Gagal memuat jenis time-off',
                style: TextStyle(fontSize: 12, color: Colors.red.shade400),
              ),
            ),
            GestureDetector(
              onTap: _loadTimeOffTypes,
              child: const Icon(
                CupertinoIcons.refresh,
                size: 17,
                color: kNavy,
              ),
            ),
          ],
        ),
      );
    }

    if (_timeOffTypes.isEmpty) {
      return _fieldWrapper(
        alignment: Alignment.centerLeft,
        child: Text(
          'Tidak ada jenis time-off',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      );
    }

    return _fieldWrapper(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedTimeOffType,
          isExpanded: true,
          hint: const Text(
            'Pilih jenis time-off',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          icon: const Icon(
            CupertinoIcons.chevron_down,
            size: 17,
            color: Colors.grey,
          ),
          items: _timeOffTypes.map((item) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: item,
              child: Text(
                item['timeoffname']?.toString() ?? '-',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (v) => setSheetState(() => _selectedTimeOffType = v),
        ),
      ),
    );
  }

  Widget _buildRequestDateField(StateSetter setSheetState) {
    String dateText = 'Pilih tanggal';

    if (_requestStartDate != null) {
      if (_requestEndDate != null && _requestEndDate != _requestStartDate) {
        dateText = '${_formatRequestDate(_requestStartDate!)} - '
            '${_formatRequestDate(_requestEndDate!)}';
      } else {
        dateText = _formatRequestDate(_requestStartDate!);
      }
    }

    final hasDate = _requestStartDate != null;

    return InkWell(
      onTap: () => _selectRequestDate(setSheetState),
      borderRadius: BorderRadius.circular(13),
      child: _fieldWrapper(
        child: Row(
          children: [
            const Icon(CupertinoIcons.calendar, size: 19, color: kNavy),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                dateText,
                style: TextStyle(
                  fontSize: 13,
                  color: hasDate ? kTextPrimary : Colors.grey,
                  fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonField() {
    return TextField(
      controller: _reasonController,
      maxLines: 4,
      style: const TextStyle(fontSize: 13, color: kTextPrimary),
      decoration: InputDecoration(
        hintText: 'Tuliskan alasan pengajuan...',
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        filled: true,
        fillColor: kFieldBg,
        contentPadding: const EdgeInsets.all(14),
        border: _fieldBorder(),
        enabledBorder: _fieldBorder(),
        focusedBorder: _fieldBorder(color: kNavy, width: 1.2),
      ),
    );
  }

  OutlineInputBorder _fieldBorder({Color? color, double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(
        color: color ?? Colors.grey.shade200,
        width: width,
      ),
    );
  }

  Widget _fieldWrapper({
    required Widget child,
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: alignment,
      decoration: BoxDecoration(
        color: kFieldBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Future<void> _selectRequestDate(StateSetter setSheetState) async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _requestStartDate != null
          ? DateTimeRange(
              start: _requestStartDate!,
              end: _requestEndDate ?? _requestStartDate!,
            )
          : null,
    );

    if (picked == null) return;

    setSheetState(() {
      _requestStartDate = picked.start;
      _requestEndDate = picked.end;
    });
  }

  // ============================================================
  // ATTACHMENTS
  // ============================================================

  Widget _buildAttachmentSection(StateSetter setSheetState) {
    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
            child: _buildAttachmentBox(
              index,
              _selectedAttachments[index],
              setSheetState,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAttachmentBox(
    int index,
    PlatformFile? file,
    StateSetter setSheetState,
  ) {
    final hasFile = file != null;

    return InkWell(
      onTap: () => _pickAttachment(index, setSheetState),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: hasFile ? kNavy.withOpacity(0.06) : kFieldBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasFile ? kNavy.withOpacity(0.25) : Colors.grey.shade200,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasFile
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.cloud_upload,
                    size: 24,
                    color: hasFile ? kNavy : Colors.grey.shade700,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasFile ? file.name : 'Upload',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: hasFile ? kNavy : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            if (hasFile)
              Positioned(
                top: 2,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    setSheetState(() => _selectedAttachments[index] = null);
                  },
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAttachment(
    int index,
    StateSetter sheetSetState,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      if (file.size > 10 * 1024 * 1024) {
        _snack('Ukuran file maksimal 10 MB.');
        return;
      }

      sheetSetState(() => _selectedAttachments[index] = file);
    } catch (e) {
      _snack('Gagal memilih file: $e');
    }
  }
}
