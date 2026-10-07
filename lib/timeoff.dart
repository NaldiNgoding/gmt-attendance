import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeOffPage extends StatefulWidget {
  const TimeOffPage({super.key});

  @override
  State<TimeOffPage> createState() => _TimeOffPageState();
}

class _TimeOffPageState extends State<TimeOffPage> {
  // ============================================================
  // API
  // ============================================================
  static const String baseUrl = 'http://localhost:8000/api';
  // ============================================================
  // COLORS
  // ============================================================

  static const Color kNavy = Color(0xFF0D47A1);
  static const Color kNavyDark = Color(0xFF083B82);
  static const Color kBackground = Color(0xFFF6F8FC);

  // ============================================================
  // USER
  // ============================================================

  String _employeeId = '';

  // ============================================================
  // LEAVE BALANCE
  // ============================================================

  double _remainingBalance = 0;

  int _balanceYear = DateTime.now().year;

  bool _isLoading = true;

  String? _errorMessage;

  // ============================================================
  // TIME SELECTOR
  // ============================================================

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<String> _months = [
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

  List<Map<String, dynamic>> _historyList = [];
  bool _isLoadingHistory = false;
  String? _historyError;

// ============================================================
// REQUEST TIME-OFF FORM
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
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadLeaveBalance();
    _loadTimeOffTypes();
  }

  // ============================================================
  // LOAD LEAVE BALANCE
  // ============================================================

  Future<void> _loadLeaveBalance() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final prefs = await SharedPreferences.getInstance();

      final employeeId = prefs.getString('empid') ?? '';

      if (employeeId.isEmpty) {
        throw Exception(
          'Employee ID tidak ditemukan.',
        );
      }

      final year = DateTime.now().year;

      final uri = Uri.parse(
        '$baseUrl/my-leave-balance',
      ).replace(
        queryParameters: {
          'employeeid': employeeId,
          'year': year.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded['success'] != true) {
        throw Exception(
          decoded['message'] ?? 'Gagal mengambil saldo cuti.',
        );
      }

      final data = Map<String, dynamic>.from(
        decoded['data'] ?? {},
      );

      final remaining = double.tryParse(
            data['remaining_balance']?.toString() ?? '0',
          ) ??
          0;

      if (!mounted) return;

      setState(() {
        _employeeId = employeeId;

        _balanceYear = int.tryParse(
              data['year']?.toString() ?? '',
            ) ??
            year;

        _remainingBalance = remaining;

        _isLoading = false;
      });

      await _loadTimeoffHistory();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadTimeoffHistory() async {
    if (_employeeId.isEmpty) return;

    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final uri = Uri.parse(
        '$baseUrl/my-timeoff-history',
      ).replace(
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
          json['message']?.toString() ?? 'Gagal mengambil riwayat',
        );
      }

      setState(() {
        _historyList = List<Map<String, dynamic>>.from(
          json['data'] ?? [],
        );
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _historyError = e.toString();
        _isLoadingHistory = false;
        _historyList = [];
      });
    }
  }

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
        headers: {
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

      final data = List<Map<String, dynamic>>.from(
        decoded['data'] ?? [],
      );

      if (!mounted) return;

      setState(() {
        _timeOffTypes = data;
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

  Widget _buildMonthDropdown() {
    return Expanded(
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _selectedMonth,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
            ),
            items: List.generate(
              12,
              (index) {
                final month = index + 1;

                return DropdownMenuItem<int>(
                  value: month,
                  child: Text(
                    _months[index],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
            onChanged: (value) async {
              if (value == null || value == _selectedMonth) return;

              setState(() {
                _selectedMonth = value;
              });

              await _loadTimeoffHistory();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildYearDropdown() {
    final currentYear = DateTime.now().year;

    return Expanded(
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _selectedYear,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
            ),
            items: List.generate(
              5,
              (index) {
                final year = currentYear - index;

                return DropdownMenuItem<int>(
                  value: year,
                  child: Text(
                    year.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
            onChanged: (value) async {
              if (value == null || value == _selectedYear) return;

              setState(() {
                _selectedYear = value;
              });

              await _loadTimeoffHistory();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_isLoadingHistory) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: const Center(
          child: CircularProgressIndicator(
            color: kNavy,
          ),
        ),
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
            style: TextStyle(
              fontSize: 13,
              color: Colors.red.shade400,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_historyList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 35),
        child: const Center(
          child: Text(
            'Tidak ada riwayat pengajuan',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(
        _historyList.length,
        (index) {
          final item = _historyList[index];
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatusBadge(
                  item['status']?.toString() ?? '-',
                ),
                if (status.trim().toLowerCase() == 'rejected' &&
                    rejectNote.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.15),
                      ),
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
                          rejectNote,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final normalizedStatus = status.trim().toLowerCase();

    Color backgroundColor;
    Color textColor;

    if (normalizedStatus == 'approved') {
      backgroundColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
    } else if (normalizedStatus == 'rejected') {
      backgroundColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
    } else if (normalizedStatus == 'pending') {
      backgroundColor = Colors.yellow.shade50;
      textColor = Colors.yellow.shade700;
    } else {
      backgroundColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor.withOpacity(0.25),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  void _showRequestTimeOffSheet() {
    _resetTimeOffForm();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return _buildRequestTimeOffSheet(
              sheetContext,
              setSheetState,
            );
          },
        );
      },
    );
  }

  Widget _buildRequestTimeOffSheet(
    BuildContext sheetContext,
    StateSetter setSheetState,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.55,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              // ======================================================
              // DRAG HANDLE
              // ======================================================
              Padding(
                padding: const EdgeInsets.only(
                  top: 10,
                  bottom: 6,
                ),
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // ======================================================
              // HEADER
              // ======================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  4,
                  16,
                  14,
                ),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                      },
                      splashRadius: 20,
                      icon: const Icon(
                        CupertinoIcons.xmark,
                        size: 19,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),

              // ======================================================
              // FORM
              // ======================================================
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    30,
                  ),
                  children: [
                    _buildRequestForm(setSheetState),
                  ],
                ),
              ),
            ],
          );
        },
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
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 10),
        _buildAttachmentSection(setSheetState),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isSubmittingTimeOff
                ? null
                : () => _submitTimeOff(setSheetState),
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
        ),
      ],
    );
  }

  Widget _buildFormLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF252525),
      ),
    );
  }

  Widget _buildTimeOffTypeField(StateSetter setSheetState) {
    if (_isLoadingTimeOffTypes) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: kNavy,
            ),
          ),
        ),
      );
    }

    if (_timeOffTypeError != null) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Gagal memuat jenis time-off',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade400,
                ),
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
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          'Tidak ada jenis time-off',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedTimeOffType,
          isExpanded: true,
          hint: const Text(
            'Pilih jenis time-off',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          icon: const Icon(CupertinoIcons.chevron_down,
              size: 17, color: Colors.grey),
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
          onChanged: (value) {
            setSheetState(() {
              _selectedTimeOffType = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildRequestDateField(StateSetter setSheetState) {
    String dateText = 'Pilih tanggal';

    if (_requestStartDate != null) {
      if (_requestEndDate != null && _requestEndDate != _requestStartDate) {
        dateText = '${_formatRequestDate(_requestStartDate!)}'
            ' - '
            '${_formatRequestDate(_requestEndDate!)}';
      } else {
        dateText = _formatRequestDate(_requestStartDate!);
      }
    }

    return InkWell(
      onTap: () => _selectRequestDate(setSheetState),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.calendar,
              size: 19,
              color: kNavy,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                dateText,
                style: TextStyle(
                  fontSize: 13,
                  color: _requestStartDate == null
                      ? Colors.grey
                      : const Color(0xFF252525),
                  fontWeight: _requestStartDate == null
                      ? FontWeight.normal
                      : FontWeight.w600,
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

  Future<void> _selectRequestDate(
    StateSetter setSheetState,
  ) async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(
        now.year + 1,
        12,
        31,
      ),
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

  String _formatRequestDate(DateTime date) {
    const months = [
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

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  Widget _buildReasonField() {
    return TextField(
      controller: _reasonController,
      maxLines: 4,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF252525),
      ),
      decoration: InputDecoration(
        hintText: 'Tuliskan alasan pengajuan...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: kNavy,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentSection(StateSetter setSheetState) {
    return Row(
      children: List.generate(
        3,
        (index) {
          final file = _selectedAttachments[index];

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == 2 ? 0 : 8,
              ),
              child: _buildAttachmentBox(
                index,
                file,
                setSheetState,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttachmentBox(
    int index,
    PlatformFile? file,
    StateSetter setSheetState,
  ) {
    final bool hasFile = file != null;

    return InkWell(
      onTap: () => _pickAttachment(
        index,
        setSheetState,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: hasFile ? kNavy.withOpacity(0.06) : const Color(0xFFF8FAFD),
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
                    setSheetState(() {
                      _selectedAttachments[index] = null;
                    });
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
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'pdf',
        ],
      );
      if (file == null) {
        return;
      }
      final fileSize = await file.length();
      if (fileSize != null && fileSize > 10 * 1024 * 1024) {
        _showTimeOffMessage('Ukuran file maksimal 10 MB.');
        return;
      }

      sheetSetState(() {
        _selectedAttachments[index] = file;
      });
    } catch (e) {
      _showTimeOffMessage('Gagal memilih file: $e');
    }
  }

  Future<String?> _encodeAttachment(PlatformFile? file) async {
    if (file == null) {
      return null;
    }

    final bytes = await file.readAsBytes();

    return base64Encode(bytes);
  }

  String _formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  String _formatApiDateTime(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '${date.year}-$month-$day '
        '$hour:$minute:$second';
  }

  Future<void> _submitTimeOff(StateSetter sheetSetState) async {
    if (_selectedTimeOffType == null) {
      _showTimeOffMessage(
        'Silakan pilih jenis time-off.',
      );
      return;
    }

    if (_requestStartDate == null || _requestEndDate == null) {
      _showTimeOffMessage(
        'Silakan pilih tanggal time-off.',
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      _showTimeOffMessage(
        'Silakan isi alasan pengajuan.',
      );
      return;
    }

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

    final prefs = await SharedPreferences.getInstance();
    final createdBy = prefs.getString('username') ?? '';
    sheetSetState(() {
      _isSubmittingTimeOff = true;
    });

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

      final response = await http.post(Uri.parse('$baseUrl/createtimeoffdata'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: jsonEncode(body));

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          responseData['success'] == true) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        _resetTimeOffForm();
        await _loadLeaveBalance();
        _showTimeOffMessage('Pengajuan Time-Off berhasil dikirim.');
      } else {
        throw Exception(
          responseData['message'] ?? 'Gagal mengajukan Time-Off.',
        );
      }
    } catch (e) {
      sheetSetState(() {
        _isSubmittingTimeOff = false;
      });

      _showTimeOffMessage('Gagal mengajukan Time-Off: $e');
    }
  }

  void _showTimeOffMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetTimeOffForm() {
    if (!mounted) return;

    _reasonController.clear();

    setState(() {
      _selectedTimeOffType = null;
      _requestStartDate = null;
      _requestEndDate = null;

      _selectedAttachments = List<PlatformFile?>.filled(
        3,
        null,
      );

      _isSubmittingTimeOff = false;
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
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
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D47A1),
                Color(0xFF1E88E5),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          18,
          16,
          30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // TITLE
            // ==================================================

            const Text(
              'Cuti Karyawan/ti Tahunan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kNavy,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // LEAVE BALANCE CARD
            // ==================================================

            _buildLeaveBalanceSection(),

            const SizedBox(
              height: 24,
            ),

            // ==================================================
            // TEMPORARY PLACEHOLDER
            // ==================================================

            Row(
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
                  onPressed: _showRequestTimeOffSheet,
                  icon: const Icon(
                    CupertinoIcons.add,
                    size: 16,
                  ),
                  label: const Text(
                    'Ajukan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
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

  // ============================================================
  // LEAVE BALANCE SECTION
  // ============================================================

  Widget _buildLeaveBalanceSection() {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        height: 145,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            18,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: kNavy,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorCard();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          18,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.05,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ================================================
          // ICON
          // ================================================

          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kNavy.withOpacity(
                0.08,
              ),
              borderRadius: BorderRadius.circular(
                16,
              ),
            ),
            child: const Icon(
              CupertinoIcons.calendar,
              color: kNavy,
              size: 28,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          // ================================================
          // BALANCE
          // ================================================

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
                const SizedBox(
                  height: 3,
                ),
                Text(
                  '${_formatBalance()} Hari',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: kNavy,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
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

  // ============================================================
  // ERROR CARD
  // ============================================================

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          18,
        ),
      ),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: Colors.red.shade400,
            size: 38,
          ),
          const SizedBox(
            height: 10,
          ),
          const Text(
            'Gagal mengambil saldo cuti',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kNavy,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          ElevatedButton(
            onPressed: _loadLeaveBalance,
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text(
              'Coba Lagi',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT BALANCE
  // ============================================================

  String _formatBalance() {
    if (_remainingBalance == _remainingBalance.truncateToDouble()) {
      return _remainingBalance.toInt().toString();
    }

    return _remainingBalance.toStringAsFixed(1);
  }
}
