import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class ApprovalPage extends StatefulWidget {
  const ApprovalPage({super.key});

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  // ============================================================
  // API
  // ============================================================

  static const String baseUrl = 'http://localhost:8000/api';

  // ============================================================
  // COLORS
  // ============================================================

  static const Color kNavy = Color(0xFF0D47A1);
  static const Color kNavyDark = Color(0xFF083B82);
  static const Color kBackground = Color(0xFFF8F8F8);
  static const Color kGreen = Color(0xFF4CAF50);
  static const Color kOrange = Color(0xFFFF9800);

  // ============================================================
  // TAB
  // ============================================================

  int _selectedTab = 0;

  // 0 = All
  // 1 = Attendance
  // 2 = Time-Off
  // 3 = Overtime
  int _selectedCategory = 0;

  // ============================================================
  // USER
  // ============================================================

  String _employeeId = '';

  // ============================================================
  // DATA
  // ============================================================

  List<Map<String, dynamic>> _approvalList = [];
  bool _isLoading = true;
  bool _isApproving = false;
  String? _errorMessage;

  // ============================================================
  // SEARCH
  // ============================================================

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadEmployeeId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD EMPLOYEE ID
  // ============================================================

  Future<void> _loadEmployeeId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final empId = prefs.getString('empid') ?? '';

      if (empId.isEmpty) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _errorMessage = 'Employee ID tidak ditemukan.';
        });

        return;
      }

      setState(() {
        _employeeId = empId;
      });

      await _fetchApprovals();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal membaca data user: $e';
      });
    }
  }

  // ============================================================
  // FETCH APPROVAL
  // ============================================================

  Future<void> _fetchApprovals() async {
    if (_employeeId.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tab = _selectedTab == 0 ? 'pending' : 'history';

      final uri = Uri.parse(
        '$baseUrl/attendance-approvals',
      ).replace(
        queryParameters: {
          'employeeid': _employeeId,
          'tab': tab,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'HTTP ${response.statusCode}';
        });

        return;
      }

      final decoded = jsonDecode(response.body);

      if (decoded['success'] != true) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              decoded['message'] ?? 'Gagal mengambil data approval.';
        });

        return;
      }

      final rawData = decoded['data'];

      if (rawData is! List) {
        setState(() {
          _approvalList = [];
          _isLoading = false;
        });

        return;
      }

      final result = <Map<String, dynamic>>[];

      for (final item in rawData) {
        if (item is Map) {
          result.add(
            Map<String, dynamic>.from(item),
          );
        }
      }

      setState(() {
        _approvalList = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Tidak dapat terhubung ke server.';
      });
    }
  }

  // ============================================================
  // TAB CHANGE
  // ============================================================

  Future<void> _changeTab(int index) async {
    if (_isApproving) return;

    if (_selectedTab == index) return;

    setState(() {
      _selectedTab = index;

      // Reset category ketika pindah tab
      _selectedCategory = 0;
    });

    await _fetchApprovals();
  }

  // ============================================================
  // CATEGORY CHANGE
  // ============================================================

  void _changeCategory(int index) {
    setState(() {
      _selectedCategory = index;
    });
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Search Approval',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kNavy,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      CupertinoIcons.clear,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari nama, NIK, atau keterangan...',
                  prefixIcon: const Icon(
                    CupertinoIcons.search,
                    color: kNavy,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F6F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // FILTER DATA
  // ============================================================

  List<Map<String, dynamic>> get _filteredApprovalList {
    List<Map<String, dynamic>> result = List.from(_approvalList);

    // ----------------------------------------------------------
    // CATEGORY
    // ----------------------------------------------------------

    if (_selectedCategory == 1) {
      result = result.where((item) {
        final type = (item['approval_type'] ?? '').toString().toLowerCase();

        return type == 'outside area' || type.contains('attendance');
      }).toList();
    } else if (_selectedCategory == 2) {
      result = result.where((item) {
        final type = (item['approval_type'] ?? '').toString().toLowerCase();

        return type.contains('time');
      }).toList();
    } else if (_selectedCategory == 3) {
      result = result.where((item) {
        final type = (item['approval_type'] ?? '').toString().toLowerCase();

        return type.contains('overtime') || type.contains('lembur');
      }).toList();
    }

    // ----------------------------------------------------------
    // SEARCH
    // ----------------------------------------------------------

    if (_searchQuery.isNotEmpty) {
      result = result.where((item) {
        final name = (item['employee_name'] ?? '').toString().toLowerCase();
        final nik = (item['employee_nik'] ?? '').toString().toLowerCase();
        final type = (item['approval_type'] ?? '').toString().toLowerCase();
        final note = (item['note'] ?? '').toString().toLowerCase();

        return name.contains(_searchQuery) ||
            nik.contains(_searchQuery) ||
            type.contains(_searchQuery) ||
            note.contains(_searchQuery);
      }).toList();
    }

    return result;
  }

  // ============================================================
  // APPROVE ONE
  // ============================================================

  Future<void> _approveOne(
    Map<String, dynamic> item,
  ) async {
    if (_isApproving) return;

    final approvalId = item['approval_id'];

    if (approvalId == null) {
      _showMessage(
        'Approval ID tidak ditemukan.',
        error: true,
      );

      return;
    }

    final confirmed = await _showConfirmation(
      title: 'Approve Request',
      message: 'Apakah Anda yakin ingin menyetujui request ini?',
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _isApproving = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/attendance-approvals/approve',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'employeeid': int.tryParse(_employeeId),
          'approvalid': approvalId,
        }),
      );

      if (!mounted) return;

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded['success'] == true) {
        _showMessage(
          'Approval berhasil.',
        );

        await _fetchApprovals();
      } else {
        _showMessage(
          decoded['message'] ?? 'Approval gagal.',
          error: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Gagal melakukan approval.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApproving = false;
        });
      }
    }
  }

  //============================================================
  // REJECT ONE
  //============================================================

  Future<void> _rejectOne(
    Map<String, dynamic> item,
  ) async {
    if (_isApproving) return;

    final approvalId = item['approval_id'];

    if (approvalId == null) {
      _showMessage(
        'Approval ID tidak ditemukan.',
        error: true,
      );

      return;
    }

    final rejectNote = await _showRejectDialog();

    if (rejectNote == null) {
      return;
    }

    setState(() {
      _isApproving = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/attendance-approvals/reject',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'employeeid': int.tryParse(_employeeId),
          'approvalid': approvalId,
          'rejectnote': rejectNote,
        }),
      );

      if (!mounted) return;
      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['success'] == true) {
        _showMessage(
          'Time-Off berhasil di-reject.',
        );
        await _fetchApprovals();
      } else {
        _showMessage(
          decoded['message'] ?? 'Reject Time-Off gagal.',
          error: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        'Gagal melakukan reject.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApproving = false;
        });
      }
    }
  }

  // ============================================================
  // APPROVE ALL
  // ============================================================

  Future<void> _approveAll() async {
    if (_isApproving) return;

    if (_selectedTab != 0) return;

    final pendingItems = _filteredApprovalList;

    if (pendingItems.isEmpty) {
      return;
    }

    final approvalIds = pendingItems
        .map(
          (item) => item['approval_id'],
        )
        .where(
          (id) => id != null,
        )
        .toList();

    if (approvalIds.isEmpty) {
      return;
    }

    final confirmed = await _showConfirmation(
      title: 'Approve All',
      message: 'Semua approval yang tampil akan disetujui.',
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _isApproving = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/attendance-approvals/approve-all',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'employeeid': int.tryParse(_employeeId),
          'approvalid': approvalIds,
        }),
      );

      if (!mounted) return;

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 && decoded['success'] == true) {
        final data = decoded['data'];

        final approvedCount = data?['approved_count'] ?? 0;

        final failedCount = data?['failed_count'] ?? 0;

        if (failedCount > 0) {
          _showMessage(
            '$approvedCount berhasil, '
            '$failedCount gagal.',
            error: true,
          );
        } else {
          _showMessage(
            '$approvedCount approval berhasil.',
          );
        }

        await _fetchApprovals();
      } else {
        _showMessage(
          decoded['message'] ?? 'Approve All gagal.',
          error: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Gagal melakukan Approve All.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApproving = false;
        });
      }
    }
  }

  // ============================================================
  // CONFIRMATION
  // ============================================================

  Future<bool> _showConfirmation({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              20,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: kNavy,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // REJECT NOTE
  // ============================================================
  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    10,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD7D7D7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Header
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color: Colors.red,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reject Request',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: kNavy,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Masukkan alasan penolakan request ini.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Reject note
                      Text(
                        'Reject Note',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: controller,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Data yang diajukan belum sesuai.',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                          errorText: errorText,
                          filled: true,
                          fillColor: const Color(0xFFF7F8FA),
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: kNavy,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  final note = controller.text.trim();

                                  if (note.isEmpty) {
                                    setSheetState(() {
                                      errorText = 'Reject note wajib diisi.';
                                    });
                                    return;
                                  }

                                  Navigator.pop(
                                    sheetContext,
                                    note,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    return result;
  }
  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(
      context,
    ).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : kGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            12,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final items = _filteredApprovalList;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: kBackground,

        // ========================================================
        // APP BAR
        // ========================================================

        appBar: AppBar(
          title: const Text(
            'Approval',
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
            // ======================================================
            // TOP TABS
            // ======================================================

            Container(
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: _buildMainTab(
                      index: 0,
                      title: 'Need\nApproval',
                    ),
                  ),
                  Expanded(
                    child: _buildMainTab(
                      index: 1,
                      title: 'Approval\nHistory',
                    ),
                  ),
                ],
              ),
            ),

            // ======================================================
            // CATEGORY FILTER
            // ======================================================

            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(
                2,
                5,
                2,
                7,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildCategoryButton(
                      index: 0,
                      icon: CupertinoIcons.list_bullet,
                      title: 'All',
                    ),
                  ),
                  Expanded(
                    child: _buildCategoryButton(
                      index: 1,
                      icon: CupertinoIcons.map_pin_ellipse,
                      title: 'Attendance',
                    ),
                  ),
                  Expanded(
                    child: _buildCategoryButton(
                      index: 2,
                      icon: CupertinoIcons.clock,
                      title: 'Time-Off',
                    ),
                  ),
                  Expanded(
                    child: _buildCategoryButton(
                      index: 3,
                      icon: CupertinoIcons.moon,
                      title: 'Overtime',
                    ),
                  ),
                ],
              ),
            ),
            // Divider
            Container(
              height: 2,
              color: const Color(
                0xFFE5E5E5,
              ),
            ),

            // ======================================================
            // CONTENT
            // ======================================================

            Expanded(
              child: _buildContent(
                items,
              ),
            ),
          ],
        ),

        // ==========================================================
        // SEARCH BUTTON
        // ==========================================================

        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,

        floatingActionButton: SizedBox(
          width: 108,
          height: 40,
          child: FloatingActionButton.extended(
            onPressed: _openSearch,
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                36,
              ),
            ),
            icon: const Icon(
              CupertinoIcons.search,
              size: 16,
            ),
            label: const Text(
              'Search',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MAIN TAB
  // ============================================================

  Widget _buildMainTab({
    required int index,
    required String title,
  }) {
    final selected = _selectedTab == index;

    return GestureDetector(
      onTap: _isApproving ? null : () => _changeTab(index),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? kNavy
                  : const Color(
                      0xFFE0E0E0,
                    ),
              width: selected ? 3 : 1,
            ),
          ),
        ),
        child: Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
              color: selected
                  ? const Color(
                      0xFF262626,
                    )
                  : const Color(
                      0xFF333333,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY BUTTON
  // ============================================================

  Widget _buildCategoryButton({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final selected = _selectedCategory == index;

    return GestureDetector(
      onTap: _isApproving
          ? null
          : () => _changeCategory(
                index,
              ),
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        height: 48,
        margin: const EdgeInsets.symmetric(
          horizontal: 3,
        ),
        decoration: BoxDecoration(
          color: selected ? kNavy : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(
              0xFFE6E6E6,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(
                0x12000000,
              ),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? Colors.white
                  : const Color(
                      0xFF242424,
                    ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: selected
                    ? Colors.white
                    : const Color(
                        0xFF242424,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent(
    List<Map<String, dynamic>> items,
  ) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: kNavy,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: kNavy,
      onRefresh: _fetchApprovals,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          100,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: 14,
            ),
            child: _buildApprovalCard(
              items[index],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // APPROVAL CARD
  // ============================================================

  Widget _buildApprovalCard(
    Map<String, dynamic> item,
  ) {
    final name = _display(
      item['employee_name'],
    );

    final nik = _display(
      item['employee_nik'],
    );

    final type = _display(
      item['approval_type'],
    );

    final dateStart = _display(
      item['date_start'],
    );

    final dateEnd = _display(
      item['date_end'],
    );

    final reason = _display(
      item['reason'],
    );

    final rejectNote = _display(
      item['reject_note'],
    );

    final history = _selectedTab == 1;
    final status =
        history ? (item['my_approval_status'] ?? 'Approved') : 'Pending';

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kNavy.withOpacity(
                      0.08,
                    ),
                    borderRadius: BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.person_fill,
                    color: kNavy,
                    size: 23,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
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
                          color: kNavy,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        '$nik • $type',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'Rejected'
                        ? Colors.red.withOpacity(0.10)
                        : status == 'Approved'
                            ? kGreen.withOpacity(0.10)
                            : kOrange.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: status == 'Rejected'
                          ? Colors.red
                          : status == 'Approved'
                              ? kGreen
                              : kOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Icon(
                  CupertinoIcons.calendar,
                  size: 17,
                  color: Colors.grey,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    dateEnd == '-' || dateEnd == dateStart
                        ? dateStart
                        : '$dateStart - $dateEnd',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            if (reason != '-') ...[
              const SizedBox(
                height: 12,
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(
                  12,
                ),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
                child: Text(
                  reason,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],

            // ==================================================
            // REJECT NOTE — TIME OFF REJECTED
            // ==================================================
            if (history &&
                type.toLowerCase().contains('time') &&
                status == 'Rejected' &&
                rejectNote != '-') ...[
              const SizedBox(
                height: 12,
              ),
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
                    const SizedBox(
                      height: 5,
                    ),
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

            // ==================================================
            // APPROVE BUTTON
            // ==================================================

            if (!history) ...[
              const SizedBox(
                height: 14,
              ),
              if (type.toLowerCase().contains('time') ||
                  type.toLowerCase().contains('outside area') ||
                  type.toLowerCase().contains('overtime'))
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isApproving ? null : () => _rejectOne(item),
                        icon: const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 18,
                        ),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isApproving ? null : () => _approveOne(item),
                        icon: const Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          size: 18,
                        ),
                        label: const Text(
                          'Approve',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isApproving ? null : () => _approveOne(item),
                    icon: const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      size: 19,
                    ),
                    label: const Text(
                      'Approve',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    String title;

    switch (_selectedCategory) {
      case 1:
        title = 'There is no Approval needed for Attendance';
        break;

      case 2:
        title = 'There is no Approval needed for Time-Off';
        break;

      case 3:
        title = 'There is no Approval needed for Overtime';
        break;

      default:
        title = _selectedTab == 0
            ? 'There is no Approval needed for this category'
            : 'There is no Approval History for this category';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade400,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 48,
            color: Colors.red.shade400,
          ),
          const SizedBox(
            height: 14,
          ),
          const Text(
            'Failed to load approval',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: kNavy,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          ElevatedButton(
            onPressed: _fetchApprovals,
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Retry',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPER
  // ============================================================

  String _display(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    final text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '-';
    }

    return text;
  }
}
