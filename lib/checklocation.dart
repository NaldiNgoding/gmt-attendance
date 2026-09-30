import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ====== PALET WARNA ======
const Color _kNavy = Color(0xFF0B2A6F);
const Color _kBlue = Color(0xFF1D4ED8);
const Color _kBlueSoft = Color(0xFF3B82F6);
const Color _kBlueLight = Color(0xFFEAF1FF);
const Color _kBg = Color(0xFFF5F8FF);
const Color _kText = Color(0xFF0F1B3D);
const Color _kMuted = Color(0xFF6B7A99);
const Color _kOk = Color(0xFF16A34A);
const Color _kBad = Color(0xFFDC2626);
const Color _kWarn = Color(0xFFF59E0B);

// ====== KONFIGURASI API ======
// Ganti localhost:8000 dengan base URL kamu.
// Kalau backend di mesin yang sama dengan flutter web -> pakai localhost.
// Kalau flutter web di HP/browser lain -> pakai IP LAN (mis. 192.168.1.10:8000).
const String _kBaseUrl = "http://localhost:8000";

class CheckLocationPage extends StatefulWidget {
  final bool isCheckIn;

  const CheckLocationPage({super.key, required this.isCheckIn});

  @override
  State<CheckLocationPage> createState() => _CheckLocationPageState();
}

class _CheckLocationPageState extends State<CheckLocationPage> {
  // State data
  Map<String, dynamic>? locationData;
  String status = "Checking...";
  double? distanceMeter;
  bool isLoading = true;
  bool canCheckInOut = false;
  String? attendanceId;
  String? employeeId;
  String? employeeName;
  String? employeeNik;
  String? locationId;
  Map<String, dynamic>? attendanceData;
  bool hasCheckedInToday = false;

  Position? currentPosition;
  double? officeLat;
  double? officeLong;
  String? currentAddress;

  final MapController mapController = MapController();
  final String currentTileLayer = 'openstreetmap';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  // ============================================================
  // BOOTSTRAP & LOAD DATA
  // ============================================================
  Future<void> _bootstrap() async {
    debugPrint("[CheckLocation] bootstrap start");
    await _loadUserData();
    await _loadHomeData();
    await _checkLocationAccess();
    debugPrint("[CheckLocation] bootstrap done");
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      employeeId = prefs.getString("empid") ?? "";
      employeeName = prefs.getString("empname") ?? "";
      employeeNik = prefs.getString("nik") ?? "";
      locationId = prefs.getString("locationid") ?? "";
    });
    debugPrint(
        "[CheckLocation] user loaded -> empid=$employeeId, locationId=$locationId");
  }

  Future<void> _loadHomeData() async {
    if (employeeId == null || employeeId!.isEmpty) {
      debugPrint("[CheckLocation] skip loadHomeData: empid kosong");
      return;
    }
    final url = Uri.parse(
      "$_kBaseUrl/api/new_gethomedata"
      "?employeeid=$employeeId"
      "&date=${DateFormat('yyyy-MM-dd').format(DateTime.now())}",
    );
    try {
      debugPrint("[CheckLocation] GET $url");
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      debugPrint("[CheckLocation] home status=${response.statusCode}");

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        if (result['success'] == true && mounted) {
          setState(() {
            attendanceData =
                result['data']?['attendance'] as Map<String, dynamic>?;
            attendanceId = attendanceData?['id']?.toString();
            hasCheckedInToday = attendanceData?['checkin'] != null &&
                attendanceData!['checkin'].toString().isNotEmpty;
          });
        }
      }
    } catch (e, st) {
      debugPrint("[CheckLocation] loadHomeData error: $e\n$st");
    }
  }

  // ============================================================
  // CHECK LOCATION
  // ============================================================
  Future<void> _checkLocationAccess() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      status = "Checking...";
      distanceMeter = null;
      locationData = null;
      canCheckInOut = false;
      currentPosition = null;
      officeLat = null;
      officeLong = null;
      currentAddress = null;
    });

    if (locationId == null || locationId!.isEmpty) {
      _fail("LocationID tidak ditemukan!");
      return;
    }

    // 1) Ambil data lokasi kantor
    final ok = await _fetchLocationFromApi(locationId!);
    if (!ok) return;

    // 2) Minta izin lokasi
    if (!await _handleLocationPermission()) return;

    // 3) Ambil posisi GPS
    try {
      currentPosition = await _getCurrentPositionSafe();
      if (currentPosition == null) {
        _fail("Gagal mendapatkan posisi GPS (null)");
        return;
      }
    } catch (e) {
      _fail("Gagal mendapatkan posisi GPS: $e");
      return;
    }

    // 4) Reverse geocoding (Nominatim) — non-blocking, jangan sampai gagal
    //    bikin seluruh proses gagal.
    _getAddressFromLatLng(currentPosition!);

    // 5) Parse koordinat kantor
    try {
      officeLat = double.parse(locationData!["lat"].toString());
      officeLong = double.parse(locationData!["long"].toString());
    } catch (e) {
      _fail("Koordinat lokasi tidak valid: $e");
      return;
    }

    // 6) Hitung jarak
    final radius =
        double.tryParse((locationData!["radius"] ?? 100).toString()) ?? 100.0;

    distanceMeter = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      officeLat!,
      officeLong!,
    );

    canCheckInOut = distanceMeter! <= radius;
    status = canCheckInOut ? "✔ BERADA DALAM LOKASI" : "❌ DI LUAR LOKASI";

    debugPrint(
        "[CheckLocation] jarak=${distanceMeter!.toStringAsFixed(2)}m radius=${radius}m canCheckInOut=$canCheckInOut");

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  void _fail(String message) {
    debugPrint("[CheckLocation] FAIL: $message");
    if (!mounted) return;
    setState(() {
      status = message;
      isLoading = false;
    });
  }

  Future<bool> _fetchLocationFromApi(String locId) async {
    final url = Uri.parse("$_kBaseUrl/api/getlocationbyid?id=$locId");
    try {
      debugPrint("[CheckLocation] GET $url");
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      debugPrint("[CheckLocation] location status=${res.statusCode}");

      if (res.statusCode != 200) {
        _fail("Gagal memuat lokasi! Status: ${res.statusCode}");
        return false;
      }

      final result = jsonDecode(res.body) as Map<String, dynamic>;
      if (result['success'] == true &&
          result['data'] is List &&
          (result['data'] as List).isNotEmpty) {
        locationData = Map<String, dynamic>.from(result['data'][0]);
        return true;
      }

      _fail("Data lokasi tidak ditemukan!");
      return false;
    } catch (e, st) {
      debugPrint("[CheckLocation] fetchLocation error: $e\n$st");
      _fail("Error fetch lokasi: $e");
      return false;
    }
  }

  // ============================================================
  // PERMISSIONS & POSITION
  // ============================================================
  Future<bool> _handleLocationPermission() async {
    try {
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _fail('Location services are disabled.');
          return false;
        }
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _fail('Location permissions are denied');
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        _fail('Location permissions are permanently denied.');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("[CheckLocation] permission error: $e");
      _fail("Gagal cek permission: $e");
      return false;
    }
  }

  Future<Position?> _getCurrentPositionSafe() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );
    } catch (e) {
      debugPrint("[CheckLocation] getCurrentPosition error: $e");

      // Fallback ke posisi terakhir
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          debugPrint("[CheckLocation] fallback ke last known position");
          return last;
        }
      } catch (e2) {
        debugPrint("[CheckLocation] lastKnown error: $e2");
      }
      rethrow;
    }
  }

  // ============================================================
  // REVERSE GEOCODING (Nominatim)
  // ============================================================
  Future<void> _getAddressFromLatLng(Position position) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?'
      'format=jsonv2'
      '&lat=${position.latitude}'
      '&lon=${position.longitude}'
      '&zoom=18'
      '&addressdetails=1',
    );

    try {
      debugPrint("[CheckLocation] reverse geocode -> $url");
      final response = await http.get(
        url,
        headers: {
          // Nominatim wajib User-Agent yang jelas.
          'User-Agent': 'AttendanceApp/1.0 (contact@yourapp.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint("[CheckLocation] nominatim status=${response.statusCode}");
      if (response.statusCode != 200) {
        _setAddress("Alamat tidak tersedia");
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      final displayName = data['display_name'] as String?;

      if (address == null && displayName == null) {
        _setAddress("Alamat tidak ditemukan");
        return;
      }

      String pick(List<String?> keys) {
        if (address == null) return '';
        for (final k in keys) {
          if (k == null) continue;
          final v = address[k];
          if (v != null && v.toString().trim().isNotEmpty) {
            return v.toString();
          }
        }
        return '';
      }

      final parts = <String>[
        pick(['road', 'pedestrian', 'footway', 'path']),
        pick(['village', 'suburb', 'neighbourhood', 'hamlet']),
        pick(['city_district', 'town', 'city', 'municipality', 'county']),
        pick(['state']),
        pick(['postcode']),
      ].where((e) => e.trim().isNotEmpty).toList();

      _setAddress(parts.isNotEmpty
          ? parts.join(', ')
          : (displayName ?? "Alamat tidak tersedia"));
    } catch (e, st) {
      debugPrint("[CheckLocation] reverse geocoding error: $e\n$st");
      _setAddress("Gagal mengambil alamat");
    }
  }

  void _setAddress(String value) {
    if (!mounted) return;
    setState(() => currentAddress = value);
  }

  // ============================================================
  // NAVIGASI
  // ============================================================
  void _navigateToCameraPage() {
    if (!canCheckInOut && widget.isCheckIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Anda harus berada dalam radius lokasi untuk Check In"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'canProceed': true,
      'isCheckIn': widget.isCheckIn,
      'employeeId': employeeId ?? '',
      'employeeName': employeeName ?? '',
      'attendanceId': attendanceId,
      'locationData': locationData,
      'currentPosition': currentPosition,
      'canCheckInOut': canCheckInOut,
    });
  }

  // ============================================================
  // HELPERS UI
  // ============================================================
  Color get _statusColor => canCheckInOut ? _kOk : _kBad;

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBlue.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      );

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kBlueLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _kBlue, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kNavy,
          ),
        ),
      ],
    );
  }

  Widget _mapBadge({
    required Widget child,
    Color? color,
    EdgeInsets padding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    double radius = 12,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: _kNavy.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // WIDGETS
  // ============================================================
  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kNavy, _kBlue, _kBlueSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              canCheckInOut ? Icons.check_circle : Icons.cancel,
              color: _statusColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                if (distanceMeter != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Jarak: ${distanceMeter!.toStringAsFixed(2)} meter",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    if (officeLat == null || officeLong == null || currentPosition == null) {
      return Container(
        height: 250,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: _cardDecoration(),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_rounded, size: 50, color: _kBlueSoft),
              SizedBox(height: 10),
              Text("Memuat peta...", style: TextStyle(color: _kMuted)),
            ],
          ),
        ),
      );
    }

    final officePoint = LatLng(officeLat!, officeLong!);
    final userPoint =
        LatLng(currentPosition!.latitude, currentPosition!.longitude);

    final actualRadius =
        double.tryParse((locationData!["radius"] ?? 100).toString()) ?? 100.0;

    const double circleRadiusInPixels = 40.0;

    String tileUrl;
    switch (currentTileLayer) {
      case 'cartodb':
        tileUrl = 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
        break;
      case 'cyclosm':
        tileUrl =
            'https://a.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png';
        break;
      default:
        tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }

    const double fixedZoomLevel = 16.0;
    const int interactiveFlags =
        InteractiveFlag.drag | InteractiveFlag.pinchZoom;

    return Container(
      height: 300,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: _kBlue.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                center: officePoint,
                zoom: fixedZoomLevel,
                maxZoom: fixedZoomLevel,
                minZoom: fixedZoomLevel,
                interactiveFlags: interactiveFlags,
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: 'com.yourcompany.yourapp',
                  tileProvider: NetworkTileProvider(),
                  backgroundColor: _kBlueLight,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: officePoint,
                      width: circleRadiusInPixels * 2,
                      height: circleRadiusInPixels * 2,
                      builder: (ctx) => Center(
                        child: Container(
                          width: circleRadiusInPixels * 2,
                          height: circleRadiusInPixels * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _statusColor.withOpacity(0.15),
                            border: Border.all(
                              color: _statusColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [officePoint, userPoint],
                      color: _statusColor,
                      strokeWidth: 3.0,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: officePoint,
                      width: 44,
                      height: 44,
                      builder: (ctx) => Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kNavy, _kBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    Marker(
                      point: userPoint,
                      width: 44,
                      height: 44,
                      builder: (ctx) => Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _mapBadge(
                color: _kNavy.withOpacity(0.9),
                radius: 20,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radar, color: Colors.white, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      "Radius: ${actualRadius.toStringAsFixed(0)} m",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _mapBadge(
                color: _statusColor,
                radius: 20,
                child: Text(
                  canCheckInOut ? "✓ DALAM" : "✗ LUAR",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: _mapBadge(
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: _kBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text("Kantor",
                        style: TextStyle(fontSize: 10, color: _kText)),
                    const SizedBox(width: 10),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text("Anda",
                        style: TextStyle(fontSize: 10, color: _kText)),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: _mapBadge(
                child: Text(
                  "${distanceMeter?.toStringAsFixed(2) ?? '0.00'} m",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDetails() {
    if (locationData == null) {
      return const SizedBox.shrink();
    }

    final radiusValue =
        double.tryParse(locationData!["radius"]?.toString() ?? '100') ?? 100.0;

    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.location_city_rounded, "Detail Lokasi"),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kBlueLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.business, color: _kBlue, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        locationData?["locationname"]?.toString() ??
                            "Head Office",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _kNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((locationData?["address"]?.toString() ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: _kMuted, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            locationData!["address"].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kMuted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _statusColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          canCheckInOut ? Icons.check_circle : Icons.cancel,
                          color: _statusColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          canCheckInOut ? "Dalam Radius" : "Luar Radius",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _statusColor,
                          ),
                        ),
                      ],
                    ),
                    if (distanceMeter != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 26),
                        child: Text(
                          "Jarak: ${distanceMeter!.toStringAsFixed(2)} m",
                          style: const TextStyle(
                            fontSize: 12,
                            color: _kMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Radius",
                      style: TextStyle(fontSize: 11, color: _kMuted),
                    ),
                    Text(
                      "${radiusValue.toStringAsFixed(0)} m",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _kBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!canCheckInOut && distanceMeter != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kWarn.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kWarn.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${(distanceMeter! - radiusValue).toStringAsFixed(2)} m di luar radius",
                      style: TextStyle(
                        color: Colors.orange[900],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoordinateItem(
      String title, String coordinate, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  coordinate,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _navigateToCameraPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinateCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.my_location_rounded, "Koordinat"),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildCoordinateItem(
                  "Kantor",
                  "${officeLat?.toStringAsFixed(6) ?? '-'}\n${officeLong?.toStringAsFixed(6) ?? '-'}",
                  Icons.business,
                  _kBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCoordinateItem(
                  "Anda",
                  "${currentPosition?.latitude.toStringAsFixed(6) ?? '-'}\n${currentPosition?.longitude.toStringAsFixed(6) ?? '-'}",
                  Icons.person_pin_circle,
                  _statusColor,
                ),
              ),
            ],
          ),
          if (currentAddress != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kBlueLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBlue.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place, color: _kBlue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentAddress!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _kText,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildActionButton(
            label:
                widget.isCheckIn ? "LANJUT KE CHECK IN" : "LANJUT KE CHECK OUT",
            icon: widget.isCheckIn ? Icons.login : Icons.logout,
            colors: widget.isCheckIn
                ? const [_kBlue, _kBlueSoft]
                : const [_kNavy, _kBlue],
          ),
          if (!canCheckInOut && !widget.isCheckIn && hasCheckedInToday)
            _buildActionButton(
              label: "CHECK OUT (DI LUAR RADIUS)",
              icon: Icons.logout,
              colors: const [Color(0xFFB91C1C), _kBad],
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          widget.isCheckIn ? "Check In" : "Check Out",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: _kNavy,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kNavy, _kBlue],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () async {
              await _loadHomeData();
              await _checkLocationAccess();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildStatusBanner(),
                  const SizedBox(height: 16),
                  _buildMapPreview(),
                  _buildLocationDetails(),
                  _buildCoordinateCard(),
                ],
              ),
            ),
    );
  }
}
