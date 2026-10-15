import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ============================================================
// BASE URL
// ============================================================
const String kBaseUrl = 'http://localhost:8000';
// Ping endpoint — ganti ke endpoint yang benar-benar ada di server Anda.
// Kalau belum ada, buat endpoint /api/ping di backend yang return 200.
const String kPingUrl = '$kBaseUrl/api/ping';

// Fallback URL untuk deteksi internet publik (saat server lokal down).
const String kPublicPingUrl = 'https://www.google.com';

// ============================================================
// MODEL — PendingAttendance
// ============================================================
class PendingAttendance {
  final String localId;
  final String type; // 'clock_in' atau 'clock_out'
  final String employeeId;
  final String employeeName;
  final String date; // yyyy-MM-dd
  final String time; // HH:mm
  final String createdDate; // yyyy-MM-dd HH:mm:ss
  final String base64Image;
  final String locationName;
  final String locationAddress;
  final String locationCoordinate;
  final String description;
  final String requestTime;
  final bool synced;
  final int retryCount;
  final String queuedAt;
  final String? syncedAt;

  PendingAttendance({
    required this.localId,
    required this.type,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.time,
    required this.createdDate,
    required this.base64Image,
    required this.locationName,
    required this.locationAddress,
    required this.locationCoordinate,
    required this.description,
    required this.requestTime,
    this.synced = false,
    this.retryCount = 0,
    required this.queuedAt,
    this.syncedAt,
  });

  bool get isClockIn => type == 'clock_in';

  Map<String, dynamic> toMap() => {
        'local_id': localId,
        'type': type,
        'employeeid': employeeId,
        'empname': employeeName,
        'date': date,
        'time': time,
        'createddate': createdDate,
        'base64image': base64Image,
        'locationsettingname': locationName,
        'locationaddress': locationAddress,
        'locationcoordinate': locationCoordinate,
        'description': description,
        'requesttime': requestTime,
        'synced': synced,
        'retryCount': retryCount,
        'queued_at': queuedAt,
        'synced_at': syncedAt,
      };

  factory PendingAttendance.fromMap(Map<dynamic, dynamic> map) {
    return PendingAttendance(
      localId: (map['local_id'] ?? '').toString(),
      type: (map['type'] ?? 'clock_in').toString(),
      employeeId: (map['employeeid'] ?? '').toString(),
      employeeName: (map['empname'] ?? '').toString(),
      date: (map['date'] ?? '').toString(),
      time: (map['time'] ?? '').toString(),
      createdDate: (map['createddate'] ?? '').toString(),
      base64Image: (map['base64image'] ?? '').toString(),
      locationName: (map['locationsettingname'] ?? 'Office').toString(),
      locationAddress: (map['locationaddress'] ?? '').toString(),
      locationCoordinate: (map['locationcoordinate'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      requestTime: (map['requesttime'] ?? '').toString(),
      synced: map['synced'] == true,
      retryCount: int.tryParse((map['retryCount'] ?? 0).toString()) ?? 0,
      queuedAt: (map['queued_at'] ?? '').toString(),
      syncedAt: map['synced_at']?.toString(),
    );
  }

  /// Convert ke payload API saat sync ke server
  Map<String, dynamic> toApiPayload() {
    final payload = <String, dynamic>{
      "id": "",
      "employeeid": employeeId,
      "date": date,
      "createdby": employeeName,
      "createddate": createdDate,
      "status": "Present",
      "ext": "jpg",
      "data": base64Image,
      "locationsettingname": locationName,
      "locationaddress": locationAddress,
      "locationcoordinate": locationCoordinate,
      "description": description,
      "requesttime": requestTime,
    };
    if (isClockIn) {
      payload["checkin"] = time;
    } else {
      payload["checkout"] = time;
    }
    return payload;
  }
}

// ============================================================
// SERVICE — OfflineService
// ============================================================
class OfflineService {
  static const String _boxName = 'pending_attendance';

  static Future<Box> _box() => Hive.openBox(_boxName);

  /// Simpan absensi ke antrian
  static Future<String> enqueue({
    required String type, // 'clock_in' / 'clock_out'
    required String employeeId,
    required String employeeName,
    required String base64Image,
    String locationName = 'Office',
    String locationAddress = '',
    String locationCoordinate = '',
    String? description,
  }) async {
    final box = await _box();
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();

    final item = PendingAttendance(
      localId: id,
      type: type,
      employeeId: employeeId,
      employeeName: employeeName,
      date: DateFormat('yyyy-MM-dd').format(now),
      time: DateFormat('HH:mm').format(now),
      createdDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
      base64Image: base64Image,
      locationName: locationName,
      locationAddress: locationAddress,
      locationCoordinate: locationCoordinate,
      description: description ??
          (type == 'clock_in' ? 'Clock In (offline)' : 'Clock Out (offline)'),
      requestTime: DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
      synced: false,
      retryCount: 0,
      queuedAt: now.toIso8601String(),
    );

    await box.put(id, item.toMap());
    return id;
  }

  /// Ambil semua item (sorted terbaru dulu)
  static Future<List<PendingAttendance>> getAll() async {
    final box = await _box();
    final list =
        box.values.map((e) => PendingAttendance.fromMap(e as Map)).toList();
    list.sort((a, b) => b.queuedAt.compareTo(a.queuedAt));
    return list;
  }

  /// Ambil yang belum tersinkron
  static Future<List<PendingAttendance>> getPending() async {
    final all = await getAll();
    return all.where((e) => !e.synced).toList();
  }

  /// Hitung jumlah pending
  static Future<int> pendingCount() async {
    return (await getPending()).length;
  }

  /// Hitung total item (termasuk yang synced)
  static Future<int> totalCount() async {
    return (await getAll()).length;
  }

  /// Update status synced
  static Future<void> markSynced(String localId) async {
    final box = await _box();
    final raw = box.get(localId);
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      map['synced'] = true;
      map['synced_at'] = DateTime.now().toIso8601String();
      await box.put(localId, map);
    }
  }

  /// Increment retry count
  static Future<void> incrementRetry(String localId) async {
    final box = await _box();
    final raw = box.get(localId);
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      map['retryCount'] = ((map['retryCount'] ?? 0) as int) + 1;
      await box.put(localId, map);
    }
  }

  /// Hapus 1 item
  static Future<void> remove(String localId) async {
    final box = await _box();
    await box.delete(localId);
  }

  /// Hapus semua item yang sudah synced
  static Future<int> clearSynced() async {
    final box = await _box();
    final keysToDelete = <dynamic>[];
    for (final key in box.keys) {
      final v = box.get(key);
      if (v is Map && v['synced'] == true) {
        keysToDelete.add(key);
      }
    }
    await box.deleteAll(keysToDelete);
    return keysToDelete.length;
  }

  /// Hapus semua (danger)
  static Future<void> clearAll() async {
    final box = await _box();
    await box.clear();
  }

  /// Kirim 1 item ke server
  static Future<bool> _sendOne(PendingAttendance item) async {
    try {
      final endpoint = item.isClockIn
          ? '$kBaseUrl/api/new_clockin'
          : '$kBaseUrl/api/new_clockout';

      final res = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(item.toApiPayload()),
          )
          .timeout(const Duration(seconds: 30));

      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Sync semua pending
  static Future<SyncResult> syncAll() async {
    final items = await getPending();
    int success = 0;
    int failed = 0;
    final failedItems = <PendingAttendance>[];

    for (final item in items) {
      final ok = await _sendOne(item);
      if (ok) {
        await markSynced(item.localId);
        success++;
      } else {
        await incrementRetry(item.localId);
        failed++;
        failedItems.add(item);
      }
    }

    return SyncResult(
      success: success,
      failed: failed,
      failedItems: failedItems,
    );
  }
}

// ============================================================
// RESULT
// ============================================================
class SyncResult {
  final int success;
  final int failed;
  final List<PendingAttendance> failedItems;

  SyncResult({
    required this.success,
    required this.failed,
    required this.failedItems,
  });

  bool get nothingToSync => success == 0 && failed == 0;
  bool get allSuccess => failed == 0 && success > 0;
}

// ============================================================
// VIEW — OfflineAttendancePage
// ============================================================
class OfflineAttendancePage extends StatefulWidget {
  const OfflineAttendancePage({super.key});

  @override
  State<OfflineAttendancePage> createState() => _OfflineAttendancePageState();
}

class _OfflineAttendancePageState extends State<OfflineAttendancePage> {
  // ==================== COLORS ====================
  static const Color kPrimary = Color(0xFF1E88E5);
  static const Color kSecondary = Color(0xFF0D47A1);
  static const Color kSuccess = Color(0xFF4CAF50);
  static const Color kWarning = Color(0xFFFF9800);
  static const Color kDanger = Color(0xFFF44336);
  static const Color kBackground = Color(0xFFF6F7FA);
  static const Color kDarkText = Color(0xFF172033);
  static const Color kMutedText = Color(0xFF7A8496);
  static const Color kBorder = Color(0xFFE7EAF0);

  List<PendingAttendance> _allItems = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = await OfflineService.getAll();
    if (!mounted) return;
    setState(() {
      _allItems = items;
      _isLoading = false;
    });
  }

  Future<void> _sync() async {
    setState(() => _isSyncing = true);
    final result = await OfflineService.syncAll();
    await _load();
    if (!mounted) return;
    setState(() => _isSyncing = false);

    if (result.nothingToSync) {
      _showSnack('Tidak ada data untuk disinkronkan', kWarning);
    } else if (result.allSuccess) {
      _showSnack('${result.success} data berhasil disinkronkan', kSuccess);
    } else {
      _showSnack(
        '${result.success} berhasil, ${result.failed} gagal',
        kWarning,
      );
    }

    // Auto cleanup kalau semua sukses
    if (result.allSuccess) {
      await OfflineService.clearSynced();
      await _load();
    }
  }

  Future<void> _clearSynced() async {
    final confirm = await _confirmDialog(
      title: 'Hapus Data Tersinkron',
      message:
          'Hapus semua data yang sudah berhasil disinkronkan dari antrian?',
      confirmText: 'Hapus',
      confirmColor: kDanger,
    );
    if (confirm != true) return;

    final count = await OfflineService.clearSynced();
    await _load();
    if (!mounted) return;
    _showSnack('$count data tersinkron dihapus', kSuccess);
  }

  Future<void> _clearAll() async {
    final confirm = await _confirmDialog(
      title: 'Hapus Semua Antrian',
      message:
          'Semua data antrian (termasuk yang belum tersinkron) akan dihapus permanen. Lanjutkan?',
      confirmText: 'Hapus Semua',
      confirmColor: kDanger,
    );
    if (confirm != true) return;

    await OfflineService.clearAll();
    await _load();
    if (!mounted) return;
    _showSnack('Semua antrian dihapus', kSuccess);
  }

  Future<void> _deleteItem(PendingAttendance item) async {
    final confirm = await _confirmDialog(
      title: 'Hapus Item',
      message:
          'Hapus data ${item.isClockIn ? "Clock In" : "Clock Out"} tanggal ${item.date}?',
      confirmText: 'Hapus',
      confirmColor: kDanger,
    );
    if (confirm != true) return;

    await OfflineService.remove(item.localId);
    await _load();
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child:
                Text(confirmText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _showDetail(PendingAttendance item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildDetailSheet(item),
    );
  }

  Widget _buildDetailSheet(PendingAttendance item) {
    final color = item.isClockIn ? kSuccess : kWarning;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          item.isClockIn ? Icons.login : Icons.logout,
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.isClockIn ? 'Clock In' : 'Clock Out',
                              style: const TextStyle(
                                color: kDarkText,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _buildStatusChip(item),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Foto
                  if (item.base64Image.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        base64Decode(item.base64Image),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          color: kBackground,
                          child: const Center(
                            child: Icon(Icons.broken_image,
                                color: kMutedText, size: 40),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Info
                  _buildInfoRow('Tanggal', item.date),
                  _buildInfoRow('Jam', item.time),
                  _buildInfoRow('Nama', item.employeeName),
                  _buildInfoRow('Employee ID', item.employeeId),
                  _buildInfoRow('Lokasi', item.locationName),
                  if (item.locationAddress.isNotEmpty)
                    _buildInfoRow('Alamat', item.locationAddress),
                  if (item.locationCoordinate.isNotEmpty)
                    _buildInfoRow('Koordinat', item.locationCoordinate),
                  _buildInfoRow('Deskripsi', item.description),
                  _buildInfoRow('Dibuat', item.createdDate),
                  _buildInfoRow('Di-queue', _prettyDate(item.queuedAt)),
                  if (item.syncedAt != null)
                    _buildInfoRow('Disinkron', _prettyDate(item.syncedAt!)),
                  if (item.retryCount > 0)
                    _buildInfoRow('Percobaan gagal', '${item.retryCount}x'),

                  const SizedBox(height: 24),

                  // Action buttons
                  if (!item.synced)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteItem(item);
                        },
                        icon: const Icon(Icons.delete_outline, color: kDanger),
                        label: const Text('Hapus dari Antrian',
                            style: TextStyle(color: kDanger)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kDanger),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(PendingAttendance item) {
    if (item.synced) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kSuccess.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: kSuccess, size: 12),
            SizedBox(width: 5),
            Text(
              'Tersinkron',
              style: TextStyle(
                color: kSuccess,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    if (item.retryCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kDanger.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: kDanger, size: 12),
            const SizedBox(width: 5),
            Text(
              'Gagal ${item.retryCount}x',
              style: const TextStyle(
                color: kDanger,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kWarning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_bottom, color: kWarning, size: 12),
          SizedBox(width: 5),
          Text(
            'Menunggu',
            style: TextStyle(
              color: kWarning,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: kMutedText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: kDarkText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _prettyDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final pendingItems = _allItems.where((e) => !e.synced).toList();
    final syncedItems = _allItems.where((e) => e.synced).toList();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Antrian Offline',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_allItems.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (v) {
                if (v == 'clear_synced') _clearSynced();
                if (v == 'clear_all') _clearAll();
                if (v == 'refresh') _load();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Muat Ulang'),
                    ],
                  ),
                ),
                if (syncedItems.isNotEmpty)
                  const PopupMenuItem(
                    value: 'clear_synced',
                    child: Row(
                      children: [
                        Icon(Icons.cleaning_services_rounded,
                            size: 18, color: kSuccess),
                        SizedBox(width: 10),
                        Text('Hapus Tersinkron'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded,
                          size: 18, color: kDanger),
                      SizedBox(width: 10),
                      Text('Hapus Semua'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: kPrimary,
              child: _allItems.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        _buildSummaryCard(
                            pendingItems.length, syncedItems.length),
                        const SizedBox(height: 16),
                        if (pendingItems.isNotEmpty) ...[
                          _buildSectionHeader(
                              'Menunggu Sinkron (${pendingItems.length})',
                              kWarning),
                          const SizedBox(height: 10),
                          ...pendingItems.map(_buildItemCard),
                          const SizedBox(height: 20),
                        ],
                        if (syncedItems.isNotEmpty) ...[
                          _buildSectionHeader(
                              'Tersinkron (${syncedItems.length})', kSuccess),
                          const SizedBox(height: 10),
                          ...syncedItems.map(_buildItemCard),
                        ],
                      ],
                    ),
            ),
      floatingActionButton: pendingItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isSyncing ? null : _sync,
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(_isSyncing ? 'Sinkron...' : 'Sinkron Sekarang'),
            )
          : null,
    );
  }

  Widget _buildSummaryCard(int pending, int synced) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimary, kSecondary],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.hourglass_bottom,
              label: 'Menunggu',
              value: pending.toString(),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.25),
          ),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.playlist_add_check_rounded,
              label: 'Tersinkron',
              value: synced.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: kDarkText,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(PendingAttendance item) {
    final color = item.isClockIn ? kSuccess : kWarning;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetail(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: color.withOpacity(0.10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.base64Image.isNotEmpty
                        ? Image.memory(
                            base64Decode(item.base64Image),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              item.isClockIn
                                  ? Icons.login
                                  : Icons.logout,
                              color: color,
                            ),
                          )
                        : Icon(
                            item.isClockIn
                                ? Icons.login
                                : Icons.logout,
                            color: color,
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.isClockIn ? 'Clock In' : 'Clock Out',
                            style: const TextStyle(
                              color: kDarkText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusChip(item),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 11, color: kMutedText),
                          const SizedBox(width: 4),
                          Text(
                            item.date,
                            style: const TextStyle(
                              color: kMutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.access_time_rounded,
                              size: 11, color: kMutedText),
                          const SizedBox(width: 4),
                          Text(
                            item.time,
                            style: const TextStyle(
                              color: kMutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow
                const Icon(Icons.chevron_right_rounded,
                    color: kMutedText, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Center(
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  color: kPrimary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tidak Ada Antrian',
                style: TextStyle(
                  color: kDarkText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Semua absensi Anda sudah tersinkron ke server.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kMutedText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
