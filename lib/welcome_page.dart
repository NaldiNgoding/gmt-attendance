import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'login_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Welcome Page — Blue Luxury Theme
//  Aesthetic: Deep blue + warm amber gold, editorial typography,
//             geometric ring art, staggered entrance animations.
// ─────────────────────────────────────────────────────────────────────────────

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  // ── palette BLUE LUXURY ─────────────────────────────────────────────────
  static const _gold = Color(0xFFD4A853);
  static const _primaryBlue = Color(0xFF1A365D); // Navy blue gelap
  static const _secondaryBlue = Color(0xFF2B6CB0); // Biru medium
  static const _lightBlue = Color(0xFFEBF8FF); // Biru sangat terang
  static const _cream = Color(0xFFF7FAFC); // Putih kebiruan

  // ── animation controllers ──────────────────────────────────────────────────
  late final AnimationController _masterCtrl;
  late final AnimationController _ringCtrl; // slow infinite spin
  late final AnimationController _pulseCtrl; // logo ring pulse
  late final AnimationController _shimmerCtrl; // button shimmer

  // ── staggered element animations ──────────────────────────────────────────
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;
  late Animation<double> _badgeOpacity;
  late Animation<Offset> _badgeSlide;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _btnOpacity;
  late Animation<Offset> _btnSlide;
  late Animation<double> _footerOpacity;
  late Animation<double> _pulse;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();

    // Master entrance (1400ms)
    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Infinite slow ring rotation
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    // Logo pulse (scale breathe)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    // Button shimmer
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _buildAnimations();
    _masterCtrl.forward();
  }

  void _buildAnimations() {
    // Ring
    _ringScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack)),
    );
    _ringOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.0, 0.35, curve: Curves.easeOut)),
    );

    // Logo
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.18, 0.50, curve: Curves.easeOut)),
    );
    _logoSlide =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.18, 0.55, curve: Curves.easeOutCubic)),
    );

    // Badge
    _badgeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.30, 0.60, curve: Curves.easeOut)),
    );
    _badgeSlide =
        Tween<Offset>(begin: const Offset(0, -0.6), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.30, 0.62, curve: Curves.easeOutBack)),
    );

    // Title
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.45, 0.72, curve: Curves.easeOut)),
    );
    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.45, 0.72, curve: Curves.easeOutCubic)),
    );

    // Subtitle
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.58, 0.80, curve: Curves.easeOut)),
    );

    // Button
    _btnOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.68, 0.90, curve: Curves.easeOut)),
    );
    _btnSlide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.68, 0.92, curve: Curves.easeOutCubic)),
    );

    // Footer
    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _masterCtrl,
          curve: const Interval(0.85, 1.0, curve: Curves.easeOut)),
    );

    // Pulse (breathe 0.96 → 1.04)
    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Shimmer (0 → 1)
    _shimmer = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background photo
          Image.asset(
            'assets/images/bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: _secondaryBlue),
          ),

          // 2. Blue gradient overlay (lebih terang)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  _primaryBlue.withOpacity(0.75),
                  _primaryBlue.withOpacity(0.92),
                ],
              ),
            ),
          ),

          // 3. Bottom fade (biru, bukan hitam)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.45, 0.75, 1.0],
                colors: [
                  _primaryBlue.withOpacity(0.98),
                  _primaryBlue.withOpacity(0.85),
                  Colors.transparent,
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 4. Grain texture (lebih halus)
          CustomPaint(
            painter: _GrainPainter(),
            child: const SizedBox.expand(),
          ),

          // 5. Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // ── Badge ────────────────────────────────────────────────
                  FadeTransition(
                    opacity: _badgeOpacity,
                    child: SlideTransition(
                      position: _badgeSlide,
                      child: _Badge(),
                    ),
                  ),

                  // ── Logo + rings (fills remaining space) ─────────────────
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _ringCtrl,
                          _ringScale,
                          _ringOpacity,
                          _logoOpacity,
                          _logoSlide,
                          _pulse,
                        ]),
                        builder: (context, _) {
                          return Transform.scale(
                            scale: _ringScale.value,
                            child: Opacity(
                              opacity: _ringOpacity.value,
                              child: SizedBox(
                                width: 260,
                                height: 260,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Outer slow-spin dashed ring
                                    Transform.rotate(
                                      angle: _ringCtrl.value * 2 * math.pi,
                                      child: CustomPaint(
                                        size: const Size(260, 260),
                                        painter: _DashedRingPainter(
                                          color: _gold.withOpacity(0.35),
                                          strokeWidth: 1.0,
                                          dashCount: 48,
                                          radius: 128,
                                        ),
                                      ),
                                    ),
                                    // Middle counter-spin solid ring
                                    Transform.rotate(
                                      angle:
                                          -_ringCtrl.value * 2 * math.pi * 0.4,
                                      child: CustomPaint(
                                        size: const Size(200, 200),
                                        painter: _DashedRingPainter(
                                          color: _gold.withOpacity(0.18),
                                          strokeWidth: 0.7,
                                          dashCount: 28,
                                          radius: 98,
                                        ),
                                      ),
                                    ),
                                    // Gold arc accent (static, 3/4 circle)
                                    CustomPaint(
                                      size: const Size(220, 220),
                                      painter: _ArcAccentPainter(
                                        color: _gold,
                                        strokeWidth: 1.5,
                                        radius: 108,
                                      ),
                                    ),
                                    // Inner glow circle
                                    Container(
                                      width: 152,
                                      height: 152,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _lightBlue.withOpacity(0.08),
                                        border: Border.all(
                                          color: _gold.withOpacity(0.22),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _gold.withOpacity(0.08),
                                            blurRadius: 32,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // BACKGROUND PUTIH UNTUK LOGO
                                    Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.12),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Logo
                                    Transform.scale(
                                      scale: _pulse.value,
                                      child: FadeTransition(
                                        opacity: _logoOpacity,
                                        child: SlideTransition(
                                          position: _logoSlide,
                                          child: SizedBox(
                                            width: 90,
                                            height: 90,
                                            child: Image.asset(
                                              'assets/images/GMT3.png',
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(
                                                Icons
                                                    .precision_manufacturing_rounded,
                                                size: 50,
                                                color: _primaryBlue,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 4 gold tick marks at cardinal points
                                    ..._buildTickMarks(),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ── Title block ───────────────────────────────────────────
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: _TitleBlock(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Subtitle ──────────────────────────────────────────────────────────────
                  FadeTransition(
                    opacity: _subtitleOpacity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GoldDash(),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Integritas · Kolaboratif · Disiplin',
                            style: TextStyle(
                              fontSize: 9,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              color: _cream.withOpacity(0.65),
                              letterSpacing: 2.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _GoldDash(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 44),

                  // ── CTA Button ────────────────────────────────────────────
                  FadeTransition(
                    opacity: _btnOpacity,
                    child: SlideTransition(
                      position: _btnSlide,
                      child: _GetStartedButton(
                        shimmer: _shimmer,
                        onTap: () => Navigator.push(
                          context,
                          _FadePageRoute(page: const LoginPage()),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Footer ────────────────────────────────────────────────
                  FadeTransition(
                    opacity: _footerOpacity,
                    child: _Footer(),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTickMarks() {
    const positions = [
      Alignment(0, -1), // top
      Alignment(1, 0), // right
      Alignment(0, 1), // bottom
      Alignment(-1, 0), // left
    ];
    return positions.map((alignment) {
      return Align(
        alignment: alignment,
        child: Container(
          width: 8,
          height: 2,
          margin: alignment.y != 0
              ? EdgeInsets.symmetric(
                  horizontal: 0, vertical: alignment.y < 0 ? 0 : 0)
              : null,
          decoration: BoxDecoration(
            color: _gold.withOpacity(0.7),
            borderRadius: BorderRadius.circular(1),
          ),
          transform: alignment.x == 0 ? (Matrix4.rotationZ(math.pi / 2)) : null,
        ),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets (dengan warna biru)
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  static const _gold = Color(0xFFD4A853);
  static const _cream = Color(0xFFF7FAFC);
  static const _primaryBlue = Color(0xFF1A365D);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: _gold.withOpacity(0.4), width: 1.0),
            color: _primaryBlue.withOpacity(0.7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration:
                    const BoxDecoration(color: _gold, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'GMT ATTENDANCE',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: _cream.withOpacity(0.90),
                  letterSpacing: 3.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  static const _gold = Color(0xFFD4A853);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thin horizontal rule
        Row(
          children: [
            Expanded(
                child: Container(height: 0.5, color: _gold.withOpacity(0.35))),
            const SizedBox(width: 16),
            Text(
              'PT. GAYA MAKMUR TRACTORS',
              style: TextStyle(
                fontSize: 9,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: _gold.withOpacity(0.75),
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
                child: Container(height: 0.5, color: _gold.withOpacity(0.35))),
          ],
        ),
        const SizedBox(height: 18),

        Stack(
          alignment: Alignment.center,
          children: [
            // Gold underline accent behind text
            Positioned(
              bottom: 2,
              child: Container(
                height: 8,
                width: 168,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _gold.withOpacity(0.0),
                      _gold.withOpacity(0.25),
                      _gold.withOpacity(0.0)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              ' GMT ATTENDANCE',
              style: TextStyle(
                fontSize: 36,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: _gold,
                height: 1.1,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}

class _GoldDash extends StatelessWidget {
  static const _gold = Color(0xFFD4A853);
  @override
  Widget build(BuildContext context) {
    return Container(width: 24, height: 1, color: _gold.withOpacity(0.5));
  }
}

class _GetStartedButton extends StatefulWidget {
  final Animation<double> shimmer;
  final VoidCallback onTap;
  const _GetStartedButton({required this.shimmer, required this.onTap});

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton> {
  bool _pressed = false;
  static const _gold = Color(0xFFD4A853);
  static const _goldLight = Color(0xFFF0C97A);
  static const _primaryBlue = Color(0xFF1A365D);

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
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedBuilder(
          animation: widget.shimmer,
          builder: (context, _) {
            return Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [_gold, _goldLight, _gold],
                  stops: [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withOpacity(_pressed ? 0.2 : 0.35),
                    blurRadius: _pressed ? 12 : 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Shimmer sweep
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.translate(
                        offset: Offset(
                          (widget.shimmer.value * 1.6 - 0.3) *
                              MediaQuery.of(context).size.width,
                          0,
                        ),
                        child: Container(
                          width: 60,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.22),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Label + icon
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 16,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            color: _primaryBlue,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _primaryBlue.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: _primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  static const _cream = Color(0xFFF7FAFC);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 16, height: 0.5, color: _cream.withOpacity(0.2)),
            const SizedBox(width: 8),
            Text(
              'PT Gaya Makmur Tractors @2026',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Poppins',
                color: _cream.withOpacity(0.35),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 16, height: 0.5, color: _cream.withOpacity(0.2)),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom Painters
// ─────────────────────────────────────────────────────────────────────────────

/// Grain / noise texture overlay (lebih halus)
class _GrainPainter extends CustomPainter {
  final _rng = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 2400; i++) {
      final x = _rng.nextDouble() * size.width;
      final y = _rng.nextDouble() * size.height;
      final opacity = _rng.nextDouble() * 0.035;
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => false;
}

/// Dashed ring
class _DashedRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;
  final double radius;

  const _DashedRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final angleStep = (2 * math.pi) / dashCount;
    final dashLength = angleStep * 0.42;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * angleStep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashLength,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => false;
}

/// 3/4 arc accent with dot endpoints
class _ArcAccentPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  const _ArcAccentPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withOpacity(0.55)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 270° arc starting from top-left
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 1.25,
      math.pi * 1.5,
      false,
      paint,
    );

    // Dot at start
    final dotPaint = Paint()..color = color.withOpacity(0.8);
    final startAngle = -math.pi * 1.25;
    canvas.drawCircle(
      Offset(center.dx + radius * math.cos(startAngle),
          center.dy + radius * math.sin(startAngle)),
      2.5,
      dotPaint,
    );
    // Dot at end
    final endAngle = startAngle + math.pi * 1.5;
    canvas.drawCircle(
      Offset(center.dx + radius * math.cos(endAngle),
          center.dy + radius * math.sin(endAngle)),
      2.5,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcAccentPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom page route — elegant cross-fade transition
// ─────────────────────────────────────────────────────────────────────────────
class _FadePageRoute extends PageRoute<void> {
  final Widget page;
  _FadePageRoute({required this.page});

  @override
  Color get barrierColor => Colors.black;

  @override
  String get barrierLabel => '';

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 600);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: page,
    );
  }
}
