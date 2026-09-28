import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_home.dart';
import 'package:flutter/foundation.dart';
// ─────────────────────────────────────────────────────────────────────────────
//  Login Page — Blue Luxury Theme (Optimized)
//  Palette  : Deep Blue · Gold accent · White/Cream
//  Motion   : Staggered entrance · Gold focus ring · Button press scale
// ─────────────────────────────────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── palette BLUE LUXURY ─────────────────────────────────────────────────
  static const _gold = Color(0xFFD4A853);
  static const _primaryBlue = Color(0xFF1A365D);
  static const _secondaryBlue = Color(0xFF2B6CB0);
  static const _cream = Color(0xFFF7FAFC);

  // ── controllers ───────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  // focus state via ValueNotifier — tidak rebuild seluruh page
  final _emailFocusNotifier = ValueNotifier<bool>(false);
  final _passFocusNotifier = ValueNotifier<bool>(false);

  bool _obscure = true;
  bool _loading = false;

  // ── animations ────────────────────────────────────────────────────────────
  late final AnimationController _masterCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _floatCtrl;

  late Animation<double> _logoOpacity, _logoScale;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _formOpacity;
  late Animation<Offset> _formSlide;
  late Animation<double> _btnOpacity;
  late Animation<Offset> _btnSlide;
  late Animation<double> _shimmer;
  late Animation<double> _float;

  bool _loopsRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _emailCtrl.text = 'michael@gmtractors.net';

    _masterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200));

    _buildAnimations();

    _emailFocus.addListener(() {
      _emailFocusNotifier.value = _emailFocus.hasFocus;
    });
    _passFocus.addListener(() {
      _passFocusNotifier.value = _passFocus.hasFocus;
    });

    // Start master entrance, lalu mulai loop animasi hanya setelah selesai
    _masterCtrl.forward().whenComplete(() {
      if (!mounted) return;
      _shimmerCtrl.repeat();
      _floatCtrl.repeat(reverse: true);
      _loopsRunning = true;
    });
  }

  void _buildAnimations() {
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOut)));
    _logoScale = Tween<double>(begin: 0.70, end: 1.0).animate(CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutBack)));

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut)));
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _masterCtrl,
            curve: const Interval(0.25, 0.58, curve: Curves.easeOutCubic)));

    _formOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.42, 0.75, curve: Curves.easeOut)));
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _masterCtrl,
            curve: const Interval(0.42, 0.78, curve: Curves.easeOutCubic)));

    _btnOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.62, 0.90, curve: Curves.easeOut)));
    _btnSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _masterCtrl,
            curve: const Interval(0.62, 0.92, curve: Curves.easeOutCubic)));

    _shimmer = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    _float = Tween<double>(begin: -4.0, end: 4.0)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _shimmerCtrl.stop();
      _floatCtrl.stop();
      _loopsRunning = false;
    } else if (state == AppLifecycleState.resumed &&
        !_loopsRunning &&
        _masterCtrl.isCompleted) {
      _shimmerCtrl.repeat();
      _floatCtrl.repeat(reverse: true);
      _loopsRunning = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _masterCtrl.dispose();
    _shimmerCtrl.dispose();
    _floatCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _emailFocusNotifier.dispose();
    _passFocusNotifier.dispose();
    super.dispose();
  }

  // ── login logic ───────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (_loading) return;
    setState(() => _loading = true);

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final url = Uri.parse("http://192.168.0.151:8000/api/mobilelogin");

    try {
      final response = await http.post(
        url,
        headers: {"Accept": "application/json"},
        body: {"email": email, "password": password},
      );

      dynamic data;
      try {
        data = json.decode(response.body);
      } catch (_) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (data["success"] == true) {
        SharedPreferences prefs = await SharedPreferences.getInstance();

        final String correctEmpId = data["data"]["emp"]["id"].toString();

        prefs.setString('empid', correctEmpId);
        prefs.setString(
            'userid', data["data"]["user_map"]["userid"].toString());
        prefs.setString(
            'username', data["data"]["user_map"]["username"] ?? "-");
        prefs.setString('empname', data["data"]["emp"]["nama"] ?? "-");
        prefs.setString('nik', data["data"]["emp"]["nik"] ?? "-");
        prefs.setString('photo', data["data"]["emp"]["photo"] ?? "");
        prefs.setString(
            'locationid', data["data"]["emp"]["locationid"].toString());

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, anim, __) => const HomePage(),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        if (mounted) {
          _showError(data["message"] ?? "Email atau password salah");
        }
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) _showError("Tidak dapat terhubung ke server");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFB03A2E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryBlue,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background image + color overlay (single layer via ColorFiltered)
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                _primaryBlue.withOpacity(0.88),
                BlendMode.srcOver,
              ),
              child: Image.asset(
                'assets/images/bg.jpg',
                fit: BoxFit.cover,
                cacheWidth: 1080,
                errorBuilder: (_, __, ___) => Container(color: _secondaryBlue),
              ),
            ),
          ),

          // 2. Grain texture (cached, static)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _GrainPainter()),
            ),
          ),

          // 3. Decorative rings (top-right, static)
          Positioned(
            top: -80,
            right: -80,
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(280, 280),
                painter: _RingDecorPainter(),
              ),
            ),
          ),

          // 4. Scrollable content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 28,
                right: 28,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 36),
                  _buildLogoSection(),
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: _buildTitleSection(),
                    ),
                  ),
                  const SizedBox(height: 36),
                  FadeTransition(
                    opacity: _formOpacity,
                    child: SlideTransition(
                      position: _formSlide,
                      child: _buildForm(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _btnOpacity,
                    child: SlideTransition(
                      position: _btnSlide,
                      child: _buildSignInButton(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _btnOpacity,
                    child: _buildFooter(),
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

  Widget _buildLogoSection() {
    return FadeTransition(
      opacity: _logoOpacity,
      child: ScaleTransition(
        scale: _logoScale,
        child: Column(
          children: [
            // Static top label row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                    width: 32, height: 0.5, color: _gold.withOpacity(0.4)),
                const SizedBox(width: 12),
                Text(
                  'GMT ATTENDANCE',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: _gold.withOpacity(0.8),
                    letterSpacing: 3.2,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                    width: 32, height: 0.5, color: _gold.withOpacity(0.4)),
              ],
            ),
            const SizedBox(height: 20),

            Stack(
              alignment: Alignment.center,
              children: [
                // Static dashed ring
                RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(130, 130),
                    painter: _SmallDashedRingPainter(
                      color: _gold.withOpacity(0.35),
                      radius: 62,
                    ),
                  ),
                ),

                // Static white circle
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: _gold.withOpacity(0.3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),

                // ONLY the logo image floats (static child, no rebuild)
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _floatCtrl,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _float.value),
                      child: child,
                    ),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: Image.asset(
                        'assets/images/GMT3.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.precision_manufacturing_rounded,
                          size: 44,
                          color: _primaryBlue,
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
    );
  }

  Widget _buildTitleSection() {
    return Column(
      children: [
        Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 34,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w800,
            color: _cream,
            letterSpacing: -0.5,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Masuk untuk melanjutkan',
          style: TextStyle(
            fontSize: 14,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
            color: _cream.withOpacity(0.6),
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'Email Address'),
        const SizedBox(height: 8),
        _BlueTextField(
          controller: _emailCtrl,
          focusNode: _emailFocus,
          focusListenable: _emailFocusNotifier,
          hintText: 'nama@perusahaan.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        const _FieldLabel(label: 'Password'),
        const SizedBox(height: 8),
        _BlueTextField(
          controller: _passwordCtrl,
          focusNode: _passFocus,
          focusListenable: _passFocusNotifier,
          hintText: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscure,
          suffixIcon: IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: _cream.withOpacity(0.5),
              size: 20,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton() {
    return _BlueButton(
      shimmer: _shimmer,
      loading: _loading,
      onTap: _handleLogin,
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 20, height: 0.5, color: _cream.withOpacity(0.2)),
        const SizedBox(width: 10),
        Text(
          'PT. Gaya Makmur Tractors',
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'Poppins',
            color: _cream.withOpacity(0.35),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 10),
        Container(width: 20, height: 0.5, color: _cream.withOpacity(0.2)),
      ],
    );
  }
}

// ── Field Label ────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  static const _gold = Color(0xFFD4A853);
  static const _cream = Color(0xFFF7FAFC);
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
              color: _gold, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: _cream.withOpacity(0.85),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ── Blue Text Field ─────────────────────────────────────────────────────────
class _BlueTextField extends StatelessWidget {
  static const _gold = Color(0xFFD4A853);
  static const _cream = Color(0xFFF7FAFC);
  static const _lightBlue = Color(0xFFEBF8FF);

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueListenable<bool> focusListenable;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _BlueTextField({
    required this.controller,
    required this.focusNode,
    required this.focusListenable,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: focusListenable,
      builder: (context, isFocused, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  isFocused ? _gold.withOpacity(0.8) : _cream.withOpacity(0.15),
              width: isFocused ? 1.5 : 1.0,
            ),
            color: _lightBlue.withOpacity(isFocused ? 0.12 : 0.06),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: _gold.withOpacity(0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : const [],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _cream.withOpacity(0.92),
            ),
            cursorColor: _gold,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: _cream.withOpacity(0.35),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(
                  prefixIcon,
                  size: 18,
                  color: isFocused
                      ? _gold.withOpacity(0.9)
                      : _cream.withOpacity(0.45),
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: suffixIcon,
            ),
          ),
        );
      },
    );
  }
}

// ── Blue Button ─────────────────────────────────────────────────────────────
class _BlueButton extends StatefulWidget {
  final Animation<double> shimmer;
  final bool loading;
  final VoidCallback onTap;
  const _BlueButton({
    required this.shimmer,
    required this.loading,
    required this.onTap,
  });

  @override
  State<_BlueButton> createState() => _BlueButtonState();
}

class _BlueButtonState extends State<_BlueButton> {
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
        if (!widget.loading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Transform.scale(
        scale: _pressed ? 0.97 : 1.0,
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: widget.loading
                  ? [
                      _gold.withOpacity(0.5),
                      _goldLight.withOpacity(0.5),
                      _gold.withOpacity(0.5),
                    ]
                  : [_gold, _goldLight, _gold],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color:
                    _gold.withOpacity(_pressed || widget.loading ? 0.2 : 0.4),
                blurRadius: _pressed ? 10 : 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (!widget.loading)
                RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedBuilder(
                        animation: widget.shimmer,
                        builder: (context, _) => Transform.translate(
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
                                  Colors.white.withOpacity(0.25),
                                  Colors.white.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Center(
                child: widget.loading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _primaryBlue.withOpacity(0.7)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Masuk...',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              color: _primaryBlue.withOpacity(0.7),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Sign In',
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
                              color: _primaryBlue.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: _primaryBlue,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom Painters ─────────────────────────────────────────────────────────
class _GrainPainter extends CustomPainter {
  static ui.Image? _cachedGrain;
  static Size? _cachedSize;
  static bool _generating = false;

  @override
  void paint(Canvas canvas, Size size) {
    if ((_cachedGrain == null || _cachedSize != size) && !_generating) {
      _generateGrain(size);
    }
    if (_cachedGrain != null && _cachedSize == size) {
      canvas.drawImage(_cachedGrain!, Offset.zero, Paint());
    }
  }

  void _generateGrain(Size size) {
    _generating = true;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rng = math.Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    // 600 partikel (cukup secara visual, jauh lebih murah dari 2000)
    for (int i = 0; i < 600; i++) {
      paint.color = Colors.white.withOpacity(rng.nextDouble() * 0.03);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.5,
        paint,
      );
    }

    final picture = recorder.endRecording();
    final width = size.width.toInt().clamp(1, 4096);
    final height = size.height.toInt().clamp(1, 4096);

    picture.toImage(width, height).then((img) {
      _cachedGrain = img;
      _cachedSize = size;
      _generating = false;
    }).catchError((_) {
      _generating = false;
    });
  }

  @override
  bool shouldRepaint(_) => false;
}

class _RingDecorPainter extends CustomPainter {
  static const _gold = Color(0xFFD4A853);
  static final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width, 0);
    for (int i = 0; i < 4; i++) {
      final r = 50.0 + i * 38.0;
      _paint.color = _gold.withOpacity(0.08 + i * 0.03);
      canvas.drawCircle(center, r, _paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _SmallDashedRingPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _SmallDashedRingPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    const dashCount = 36;
    final step = (2 * math.pi) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final start = i * step;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        step * 0.45,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
