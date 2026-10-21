import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'attendance_log_screen.dart';
import 'package:flutter/services.dart';

class SubordinatePage extends StatefulWidget {
  final String employeeId;

  const SubordinatePage({
    super.key,
    required this.employeeId,
  });

  @override
  State<SubordinatePage> createState() => _SubordinatePageState();
}

class _SubordinatePageState extends State<SubordinatePage> {
  static const Color kNavy = Color(0xFF0D47A1);
  static const Color kCardColor = Color(0xFFF1F5F9);
  static const Color kTextColor = Color(0xFF252525);

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _subordinates = [];

  static const String baseUrl = 'http://localhost:8000/api';

  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSubordinates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD SUBORDINATES
  // ============================================================

  Future<void> _loadSubordinates() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.employeeId.trim().isEmpty) {
        throw Exception('Employee ID tidak ditemukan.');
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final uri = Uri.parse('$baseUrl/getsubordinates').replace(
        queryParameters: {
          'id': widget.employeeId.trim(),
          'date': today,
        },
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      debugPrint('Subordinate API Response: ${response.body}');

      final decoded = jsonDecode(response.body);

      if (decoded is! Map || decoded['success'] != true) {
        throw Exception(
          decoded is Map
              ? (decoded['message']?.toString() ??
                  'Gagal mengambil data subordinate.')
              : 'Format response API tidak valid.',
        );
      }

      final rawData = decoded['data'];

      if (rawData is! List) {
        throw Exception(
          'Format data subordinate dari API tidak valid.',
        );
      }

      final parsed = rawData
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        _subordinates = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  List<Map<String, dynamic>> get _filteredSubordinates {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return _subordinates;
    }

    return _subordinates.where((item) {
      final name = (item['nama'] ?? '').toString().toLowerCase();
      final nik = (item['nik'] ?? '').toString().toLowerCase();
      final position = (item['jobpositionname'] ?? '').toString().toLowerCase();

      return name.contains(query) ||
          nik.contains(query) ||
          position.contains(query);
    }).toList();
  }

  // ============================================================
  // TIME FORMAT
  // ============================================================

  String _formatTime(dynamic value) {
    if (value == null) return '-';

    final raw = value.toString().trim();

    if (raw.isEmpty || raw.toLowerCase() == 'null') {
      return '-';
    }

    // Contoh: 08:13:00 -> 08:13
    final match = RegExp(r'\b\d{1,2}:\d{2}\b').firstMatch(raw);

    return match?.group(0) ?? raw;
  }

  // ============================================================
  // OPEN ATTENDANCE LOG
  // ============================================================

  void _openSubordinateAttendanceLog(
    Map<String, dynamic> item,
  ) {
    final subordinateId = (item['id'] ?? '').toString();
    final subordinateName = (item['nama'] ?? '').toString();

    if (subordinateId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee ID subordinate tidak tersedia.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceLogScreen(
          key: ValueKey('subordinate-log-$subordinateId'),
          employeeId: subordinateId,
          employeeName: subordinateName,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Your Subordinate',
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
        body: Column(
          children: [
            _buildSearchField(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH FIELD
  // ============================================================

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kNavy.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          style: const TextStyle(
            fontSize: 14,
            color: kTextColor,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Cari nama, NIK, atau jabatan...',
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: kNavy,
              size: 23,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    tooltip: 'Hapus pencarian',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF5F7FB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFE4EAF2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFE4EAF2),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: kNavy,
                width: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PAGE BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: kNavy,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _loadSubordinates,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredSubordinates;

    if (filtered.isEmpty) {
      return RefreshIndicator(
        color: kNavy,
        onRefresh: _loadSubordinates,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Icon(
              Icons.people_outline_rounded,
              size: 52,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'Subordinate tidak ditemukan.'
                    : 'Belum ada data subordinate.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: kNavy,
      onRefresh: _loadSubordinates,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          return _buildSubordinateCard(filtered[index]);
        },
      ),
    );
  }

  // ============================================================
  // SUBORDINATE CARD
  // ============================================================

  Widget _buildSubordinateCard(
    Map<String, dynamic> item,
  ) {
    final name = (item['nama'] ?? '-').toString();
    final nik = (item['nik'] ?? '-').toString();
    final position = (item['jobpositionname'] ?? '-').toString();

    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE7ECF3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: kNavy.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =========================
          // EMPLOYEE INFORMATION
          // =========================
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0D47A1),
                      Color(0xFF1E88E5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      position,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'NIK: $nik',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // =========================
          // CLOCK IN / CLOCK OUT
          // =========================
          Row(
            children: [
              Expanded(
                child: _buildAttendanceTimeTile(
                  label: 'CLOCK IN',
                  value: item['checkin'],
                  icon: Icons.login_rounded,
                  color: const Color(0xFF238653),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAttendanceTimeTile(
                  label: 'CLOCK OUT',
                  value: item['checkout'],
                  icon: Icons.logout_rounded,
                  color: const Color(0xFFE58A27),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // =========================
          // ATTENDANCE LOG BUTTON
          // =========================
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton.icon(
              onPressed: () => _openSubordinateAttendanceLog(item),
              icon: const Icon(
                Icons.calendar_month_rounded,
                size: 18,
              ),
              label: const Text(
                'View Attendance Log',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: kNavy,
                backgroundColor: const Color(0xFFF0F5FC),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTimeTile({
    required String label,
    required dynamic value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(0.16),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatTime(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
        ],
      ),
    );
  }

}
