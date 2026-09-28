import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Profile Page
//  Aesthetic: Refined corporate — deep navy hero, crisp white cards,
//             geometric diagonal clip, staggered entrance animations.
// ─────────────────────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  // ── palette (matches HomePage) ────────────────────────────────────────────
  static const _navy = Color.fromARGB(255, 6, 70, 148);
  static const _navyDeep = Color(0xFF021F47);
  static const _surface = Color(0xFFF7F8FA);
  static const _success = Color(0xFF27AE60);
  static const _warning = Color(0xFFE67E22);
  static const _accent = Color(0xFF9E6CC8);
  static const _gold = Color(0xFFD4A853);

  // ── user data ─────────────────────────────────────────────────────────────
  String _name = '';
  String _userId = '';
  String _empId = '';
  String _account = '';
  bool _loaded = false;

  // ── animations ────────────────────────────────────────────────────────────
  late final AnimationController _masterCtrl;
  late final AnimationController _avatarPulse;
  late final List<Animation<double>> _cardFades;
  late final List<Animation<Offset>> _cardSlides;
  late final Animation<double> _headerFade;
  late final Animation<double> _avatarScale;

  // ── scroll ────────────────────────────────────────────────────────────────
  final _scroll = ScrollController();
  double _headerElevation = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initAnimations();
    _scroll.addListener(() {
      final e = (_scroll.offset / 60).clamp(0.0, 1.0);
      if (e != _headerElevation) setState(() => _headerElevation = e);
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('empname') ?? 'Employee';
      _userId = prefs.getString('userid') ?? '-';
      _empId = prefs.getString('empid') ?? '-';
      _account = prefs.getString('username') ?? '-';
      _loaded = true;
    });
  }

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

    // 5 staggered card groups
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

  @override
  void dispose() {
    _masterCtrl.dispose();
    _avatarPulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── initials helper ───────────────────────────────────────────────────────
  String get _initials {
    final parts = _name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty)
      return parts[0][0].toUpperCase();
    return 'U';
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero header ───────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHero()),

              // ── Stats row ─────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _Animated(
                      fade: _cardFades[0],
                      slide: _cardSlides[0],
                      child: _buildStats()),
                ),
              ),

              // ── Info card ─────────────────────────────────────────────────
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
                            color: _navy),
                        _InfoRow(
                            icon: Icons.fingerprint_rounded,
                            label: 'Employee ID',
                            value: _empId,
                            color: _success),
                        _InfoRow(
                            icon: Icons.tag_rounded,
                            label: 'User ID',
                            value: _userId,
                            color: _warning),
                        _InfoRow(
                            icon: Icons.alternate_email_rounded,
                            label: 'Account',
                            value: _account,
                            color: _accent,
                            isLast: true),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Work info card ────────────────────────────────────────────
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
                            label: 'Department',
                            value: 'General',
                            color: _navy),
                        _InfoRow(
                            icon: Icons.location_city_rounded,
                            label: 'Office',
                            value: 'Jakarta HQ',
                            color: _success),
                        _InfoRow(
                            icon: Icons.schedule_rounded,
                            label: 'Shift',
                            value: '08:30 – 17:30',
                            color: _warning,
                            isLast: true),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Settings card ─────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _Animated(
                    fade: _cardFades[3],
                    slide: _cardSlides[3],
                    child: _SectionCard(
                      title: 'Preferences',
                      icon: Icons.tune_rounded,
                      iconColor: _warning,
                      children: [
                        _SettingRow(
                            icon: Icons.notifications_rounded,
                            label: 'Notifications',
                            color: _navy,
                            onTap: () {}),
                        _SettingRow(
                            icon: Icons.lock_rounded,
                            label: 'Security & Privacy',
                            color: _accent,
                            onTap: () {}),
                        _SettingRow(
                            icon: Icons.language_rounded,
                            label: 'Language',
                            color: _success,
                            onTap: () {}),
                        _SettingRow(
                            icon: Icons.help_rounded,
                            label: 'Help Center',
                            color: _warning,
                            isLast: true,
                            onTap: () {}),
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

              // ── App version footer ────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _cardFades[4],
                    child: Center(
                      child: Text(
                        'GMT Attendance • v1.0.0',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                            letterSpacing: 0.8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Floating back button (top-left) ───────────────────────────────
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

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    return AnimatedBuilder(
      animation: Listenable.merge([_masterCtrl, _avatarPulse]),
      builder: (context, _) {
        return FadeTransition(
          opacity: _headerFade,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Diagonal clip background ────────────────────────────────
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
                      // Geometric circles (decorative)
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
                                  width: 1)),
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
                                  width: 1)),
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
                              color: Colors.white.withOpacity(0.03)),
                        ),
                      ),
                      // Dot grid pattern
                      Positioned.fill(
                          child: CustomPaint(painter: _DotGridPainter())),
                    ],
                  ),
                ),
              ),

              // ── Text content (inside header area) ───────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 56,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Avatar
                    ScaleTransition(
                      scale: _avatarScale,
                      child: Stack(
                        alignment: Alignment.center,
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
                          // Outer ring
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
                                    spreadRadius: 2),
                              ],
                            ),
                          ),
                          // Avatar circle
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF1A5BBD), Color(0xFF0D3A7A)],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _initials,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _loaded ? _name : '...',
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
                            color: Colors.white.withOpacity(0.18), width: 1),
                      ),
                      child: Text(
                        _loaded ? _account : '...',
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

              // ── Bottom spacer for the card overlap ──────────────────────
              SizedBox(height: 260 + 16),
            ],
          ),
        );
      },
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────
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
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            _StatCell(
                value: '22',
                label: 'Hadir',
                color: _success,
                icon: Icons.check_circle_rounded),
            _StatDivider(),
            _StatCell(
                value: '3',
                label: 'Cuti',
                color: _warning,
                icon: Icons.beach_access_rounded),
            _StatDivider(),
            _StatCell(
                value: '5',
                label: 'Lembur',
                color: _accent,
                icon: Icons.nights_stay_rounded),
          ],
        ),
      ),
    );
  }

  // ── Logout confirm ────────────────────────────────────────────────────────
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
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
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
                  fontSize: 14, color: Colors.grey.shade600, height: 1.5),
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
                    child: const Text('Batal',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context); // tutup bottom sheet
                      // Hapus semua data sesi
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      // Navigasi ke WelcomePage, hapus semua route sebelumnya
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          PageRouteBuilder(
                            pageBuilder: (_, animation, __) =>
                                const WelcomePage(),
                            transitionsBuilder: (_, animation, __, child) {
                              return FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                ),
                                child: child,
                              );
                            },
                            transitionDuration:
                                const Duration(milliseconds: 700),
                          ),
                          (route) => false, // hapus semua route
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
                    child: const Text('Log Out',
                        style: TextStyle(fontWeight: FontWeight.w700)),
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
      onTap: () => Navigator.pop(context),
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
  const _StatCell(
      {required this.value,
      required this.label,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withOpacity(0.10), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
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
  const _SectionCard(
      {required this.title,
      required this.icon,
      required this.iconColor,
      required this.children});

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
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2)),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade100, height: 1),
          // Children
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
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      this.isLast = false});

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
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                ],
              ),
              const Spacer(),
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

// ── Setting row ───────────────────────────────────────────────────────────────
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isLast;
  const _SettingRow(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap,
      this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 12),
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade400, size: 20),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(color: Colors.grey.shade100, height: 1, indent: 62),
      ],
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.red.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 18),
              const SizedBox(width: 8),
              Text('Log Out',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade400)),
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

/// Diagonal clip — bottom edge angles from lower-left to upper-right
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

/// Subtle dot grid pattern for the hero background
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
