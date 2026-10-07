import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import 'welcome_page.dart';
import 'attendance_home.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Profile Page — Backend-driven
//  Data sources:
//   - GET  /api/getemployeebyid?id=<empid>                  → personal
//   - GET  /api/getemploymentinfobyid?id=<empid>            → employment
//   - GET  /api/new_get_profile_picture?empid=&isthumbnail= → photo
//   - POST /api/new_upload_profile_picture                  → upload photo
// ─────────────────────────────────────────────────────────────────────────────

const String _kBaseUrl = "http://192.168.0.151:8000";

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  // ── palette ───────────────────────────────────────────────────────────────
  static const _navy = Color.fromARGB(255, 6, 70, 148);
  static const _navyDeep = Color(0xFF021F47);
  static const _surface = Color(0xFFF7F8FA);
  static const _success = Color(0xFF27AE60);
  static const _warning = Color(0xFFE67E22);
  static const _accent = Color(0xFF9E6CC8);
  static const _gold = Color(0xFFD4A853);

  // ── state ─────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _personal;
  Map<String, dynamic>? _employment;
  String _empid = '';
  bool _loading = true;
  String? _error;

  // ── profile picture state ────────────────────────────────────────────────
  Uint8List? _profileImageBytes;
  Uint8List? _profileThumbBytes;
  bool _uploadingPhoto = false;
  final ImagePicker _picker = ImagePicker();

  // ── animations ────────────────────────────────────────────────────────────
  late final AnimationController _masterCtrl;
  late final AnimationController _avatarPulse;
  late final List<Animation<double>> _cardFades;
  late final List<Animation<Offset>> _cardSlides;
  late final Animation<double> _headerFade;
  late final Animation<double> _avatarScale;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadAll();
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _avatarPulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DATA LOADING
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final empid = prefs.getString('empid') ?? '';

    if (empid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'EmpID tidak ditemukan. Silakan login ulang.';
      });
      return;
    }

    _empid = empid;

    // 1) Fetch personal + employment paralel
    final results = await Future.wait([
      _fetchJson("$_kBaseUrl/api/getemployeebyid?id=$empid"),
      _fetchJson("$_kBaseUrl/api/getemploymentinfobyid?id=$empid"),
    ]);

    if (!mounted) return;

    final personalRes = results[0];
    final employmentRes = results[1];

    if (personalRes == null) {
      setState(() {
        _loading = false;
        _error = 'Gagal memuat data karyawan dari server.';
      });
      return;
    }

    setState(() {
      _personal = _firstItem(personalRes);
      _employment = _firstItem(employmentRes);
      _loading = false;
    });

    // 2) Fetch foto profil (tidak blocking, dijalankan setelah UI tampil)
    _loadProfilePicture();
  }

  /// GET JSON, return Map response atau null kalau gagal
  Future<Map<String, dynamic>?> _fetchJson(String url) async {
    try {
      debugPrint("[Profile] GET $url");
      final res = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint("[Profile] status=${res.statusCode}");
      if (res.statusCode != 200) return null;

      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint("[Profile] error: $e\n$st");
      return null;
    }
  }

  /// Ambil item pertama dari response (data bisa List atau Map)
  Map<String, dynamic>? _firstItem(Map<String, dynamic>? res) {
    if (res == null) return null;
    final data = res['data'];
    if (data is List && data.isNotEmpty) {
      return Map<String, dynamic>.from(data.first);
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PROFILE PICTURE — GET
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _loadProfilePicture() async {
    if (_empid.isEmpty) return;

    final url = Uri.parse(
      "$_kBaseUrl/api/new_get_profile_picture"
      "?empid=$_empid&isthumbnail=0",
    );

    try {
      debugPrint("[Profile] GET $url");
      final res = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      debugPrint("[Profile] photo status=${res.statusCode}");
      if (res.statusCode != 200) return;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['success'] != true) {
        debugPrint("[Profile] photo not found: ${json['message']}");
        return;
      }

      final data = json['data'] as Map<String, dynamic>?;
      final imageB64 = data?['image_base64']?.toString();
      final thumbB64 = data?['thumbnail_base64']?.toString();

      if (!mounted) return;

      setState(() {
        if (imageB64 != null && imageB64.isNotEmpty) {
          _profileImageBytes = base64Decode(imageB64);
        }
        if (thumbB64 != null && thumbB64.isNotEmpty) {
          _profileThumbBytes = base64Decode(thumbB64);
        }
      });
    } catch (e, st) {
      debugPrint("[Profile] photo error: $e\n$st");
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PROFILE PICTURE — UPLOAD
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    if (_uploadingPhoto) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked == null) return;

      if (!mounted) return;
      setState(() => _uploadingPhoto = true);

      // Baca bytes & convert ke base64
      final bytes = await picked.readAsBytes();
      final base64Str = base64Encode(bytes);

      // Ambil ekstensi
      final ext = picked.name.contains('.')
          ? '.${picked.name.split('.').last.toLowerCase()}'
          : '.jpg';

      debugPrint("[Profile] uploading photo, ext=$ext size=${bytes.length}");

      final url = Uri.parse("$_kBaseUrl/api/new_upload_profile_picture");
      final request = http.MultipartRequest('POST', url)
        ..fields['empid'] = _empid
        ..fields['profile_base64'] = base64Str
        ..fields['image_type'] = ext;

      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);

      debugPrint("[Profile] upload status=${res.statusCode}");
      debugPrint("[Profile] upload body=${res.body}");

      Map<String, dynamic>? json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}

      if (!mounted) return;

      if (json != null && json['success'] == true) {
        _showSnack('Foto profil berhasil diupdate', success: true);
        // Refresh dari server (server re-crop/resize)
        await _loadProfilePicture();
      } else {
        _showSnack(json?['message']?.toString() ?? 'Gagal upload foto');
      }
    } catch (e, st) {
      debugPrint("[Profile] upload error: $e\n$st");
      if (mounted) _showSnack('Gagal upload foto: $e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showPhotoSourceSheet() {
    if (_uploadingPhoto) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ubah Foto Profil',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _PhotoSourceTile(
              icon: Icons.photo_camera_rounded,
              label: 'Ambil dari Kamera',
              color: _navy,
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
            _PhotoSourceTile(
              icon: Icons.photo_library_rounded,
              label: 'Pilih dari Galeri',
              color: _accent,
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? _success : Colors.red.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GETTERS
  // ══════════════════════════════════════════════════════════════════════════
  String _p(String key, [String fallback = '-']) {
    final v = _personal?[key];
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String _e(String key, [String fallback = '-']) {
    final v = _employment?[key];
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String get _name => _p('nama', 'Employee');
  String get _nik => _p('nik');
  String get _email => _p('email');
  String get _telp => _p('telp');
  String get _gender => _p('gender');
  String get _agama => _p('agama');
  String get _golDarah => _p('golongan_darah');
  String get _statusKawin => _p('status_kawin');
  String get _alamat =>
      _p('address', _p('alamat_kini1', _p('alamat_kini2', '-')));

  String get _joinDate {
    final raw = _p('tglmsk');
    if (raw == '-' || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ANIMATIONS
  // ══════════════════════════════════════════════════════════════════════════
  void _initAnimations() {
    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _avatarPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    _avatarScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _cardFades = List.generate(5, (i) {
      final start = 0.30 + i * 0.10;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _masterCtrl,
          curve: Interval(start, (start + 0.25).clamp(0.0, 1.0),
              curve: Curves.easeOut),
        ),
      );
    });
    _cardSlides = List.generate(5, (i) {
      final start = 0.30 + i * 0.10;
      return Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
          .animate(
        CurvedAnimation(
          parent: _masterCtrl,
          curve: Interval(start, (start + 0.28).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic),
        ),
      );
    });

    _masterCtrl.forward();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(color: _navy))
          else if (_error != null)
            _buildError()
          else
            _buildContent(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: FadeTransition(
              opacity: _headerFade,
              child: _BackButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded,
                  size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHero()),

        // ── Stats row ─────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverToBoxAdapter(
            child: _Animated(
              fade: _cardFades[0],
              slide: _cardSlides[0],
              child: _buildStats(),
            ),
          ),
        ),

        // ── Account Info ──────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _Animated(
              fade: _cardFades[1],
              slide: _cardSlides[1],
              child: _SectionCard(
                title: 'Account Info',
                icon: Icons.badge_rounded,
                iconColor: _navy,
                children: [
                  _InfoRow(
                    icon: Icons.person_pin_circle_rounded,
                    label: 'Full Name',
                    value: _name,
                    color: _navy,
                  ),
                  _InfoRow(
                    icon: Icons.fingerprint_rounded,
                    label: 'NIK',
                    value: _nik,
                    color: _success,
                  ),
                  _InfoRow(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    value: _email,
                    color: _warning,
                  ),
                  _InfoRow(
                    icon: Icons.phone_rounded,
                    label: 'Telephone',
                    value: _telp,
                    color: _accent,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Work Details ──────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _Animated(
              fade: _cardFades[2],
              slide: _cardSlides[2],
              child: _SectionCard(
                title: 'Work Details',
                icon: Icons.work_rounded,
                iconColor: _accent,
                children: [
                  _InfoRow(
                    icon: Icons.business_rounded,
                    label: 'Company',
                    value: _e('name'),
                    color: _navy,
                  ),
                  _InfoRow(
                    icon: Icons.apartment_rounded,
                    label: 'Department',
                    value: _e('dept_name'),
                    color: _success,
                  ),
                  _InfoRow(
                    icon: Icons.work_history_rounded,
                    label: 'Position',
                    value: _e('jobpositionname'),
                    color: _warning,
                  ),
                  _InfoRow(
                    icon: Icons.military_tech_rounded,
                    label: 'Job Level',
                    value: _e('joblevelname'),
                    color: _accent,
                  ),
                  _InfoRow(
                    icon: Icons.location_city_rounded,
                    label: 'Depo',
                    value: _e('nama_depo'),
                    color: _navy,
                  ),
                  _InfoRow(
                    icon: Icons.event_available_rounded,
                    label: 'Join Date',
                    value: _joinDate,
                    color: _success,
                  ),
                  _InfoRow(
                    icon: Icons.verified_user_rounded,
                    label: 'Status',
                    value: _e('emp_status'),
                    color: _warning,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Personal Details ──────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _Animated(
              fade: _cardFades[3],
              slide: _cardSlides[3],
              child: _SectionCard(
                title: 'Personal Details',
                icon: Icons.person_rounded,
                iconColor: _warning,
                children: [
                  _InfoRow(
                    icon: Icons.wc_rounded,
                    label: 'Gender',
                    value: _gender,
                    color: _navy,
                  ),
                  _InfoRow(
                    icon: Icons.church_rounded,
                    label: 'Religion',
                    value: _agama,
                    color: _accent,
                  ),
                  _InfoRow(
                    icon: Icons.bloodtype_rounded,
                    label: 'Blood Type',
                    value: _golDarah,
                    color: _success,
                  ),
                  _InfoRow(
                    icon: Icons.favorite_rounded,
                    label: 'Marital Status',
                    value: _statusKawin,
                    color: _warning,
                  ),
                  _InfoRow(
                    icon: Icons.home_rounded,
                    label: 'Address',
                    value: _alamat,
                    color: _navy,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Logout ────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _Animated(
              fade: _cardFades[4],
              slide: _cardSlides[4],
              child: _LogoutButton(onTap: _confirmLogout),
            ),
          ),
        ),

        // ── Footer ────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 50),
          sliver: SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _cardFades[4],
              child: Center(
                child: Text(
                  'GMT Attendance • v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HERO
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHero() {
    return AnimatedBuilder(
      animation: Listenable.merge([_masterCtrl, _avatarPulse]),
      builder: (context, _) {
        return FadeTransition(
          opacity: _headerFade,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Diagonal clip background
              ClipPath(
                clipper: _DiagonalClipper(),
                child: Container(
                  height: 260,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_navyDeep, _navy, Color(0xFF0A5FC4)],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -40,
                        right: -40,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 20,
                        right: 60,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.04),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 60,
                        left: -30,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.03),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(painter: _DotGridPainter()),
                      ),
                    ],
                  ),
                ),
              ),

              // Text + avatar content
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _avatarScale,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Pulsing ring
                          Transform.scale(
                            scale: 0.92 + (_avatarPulse.value * 0.08),
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _gold.withOpacity(
                                      0.5 - _avatarPulse.value * 0.2),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          // Gold outer ring
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _gold, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: _gold.withOpacity(0.3),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          // ── Avatar circle with photo ─────────────────
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF1A5BBD),
                                  Color(0xFF0D3A7A),
                                ],
                              ),
                              image: _profileImageBytes != null
                                  ? DecorationImage(
                                      image: MemoryImage(_profileImageBytes!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _profileImageBytes == null
                                ? Center(
                                    child: Text(
                                      _initials,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          // Online badge
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _success,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                          // ── Edit photo button ─────────────────────────
                          Positioned(
                            top: -2,
                            right: -2,
                            child: GestureDetector(
                              onTap: _showPhotoSourceSheet,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _gold, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: _uploadingPhoto
                                    ? const Padding(
                                        padding: EdgeInsets.all(7),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation(_navy),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.photo_camera_rounded,
                                        size: 14,
                                        color: _navy,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _e('jobpositionname', 'Employee'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.85),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 260 + 16),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STATS (dummy)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStats() {
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _StatCell(
              value: '-',
              label: 'Hadir',
              color: _success,
              icon: CupertinoIcons.checkmark_circle_fill,
            ),
            _StatDivider(),
            _StatCell(
              value: '-',
              label: 'Cuti',
              color: _warning,
              icon: CupertinoIcons.calendar_badge_minus,
            ),
            _StatDivider(),
            _StatCell(
              value: '-',
              label: 'Lembur',
              color: _accent,
              icon: CupertinoIcons.timer_fill,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LOGOUT
  // ══════════════════════════════════════════════════════════════════════════
  void _confirmLogout() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded,
                  color: Colors.red.shade400, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Log Out?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Anda akan keluar dari akun ini.\nData akan tetap tersimpan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          PageRouteBuilder(
                            pageBuilder: (_, animation, __) =>
                                const WelcomePage(),
                            transitionsBuilder: (_, animation, __, child) =>
                                FadeTransition(
                              opacity: CurvedAnimation(
                                  parent: animation, curve: Curves.easeOut),
                              child: child,
                            ),
                            transitionDuration:
                                const Duration(milliseconds: 700),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Log Out',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Animated extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;
  const _Animated(
      {required this.fade, required this.slide, required this.child});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        ),
        child:
            const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

// ── Stat cell ─────────────────────────────────────────────────────────────────
class _StatCell extends StatelessWidget {
  final String value, label;
  final Color color;
  final IconData icon;
  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 52, color: Colors.grey.shade100);
  }
}

// ── Section card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    )),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade100, height: 1),
          ...children,
        ],
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final bool isLast;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label disalin'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Icon(Icons.copy_rounded,
                    size: 14, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(color: Colors.grey.shade100, height: 1, indent: 62),
      ],
    );
  }
}

// ── Photo source tile (bottom sheet) ─────────────────────────────────────────
class _PhotoSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PhotoSourceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Logout button ─────────────────────────────────────────────────────────────
class _LogoutButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Log Out',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom painters
// ─────────────────────────────────────────────────────────────────────────────

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_) => false;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.06);
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
