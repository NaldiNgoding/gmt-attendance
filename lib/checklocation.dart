import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

// ====== PALET WARNA (hanya untuk tampilan) ======
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

class CheckLocationPage extends StatefulWidget {
  final bool isCheckIn; // Parameter untuk membedakan check in atau check out

  const CheckLocationPage({super.key, required this.isCheckIn});

  @override
  State<CheckLocationPage> createState() => _CheckLocationPageState();
}

class _CheckLocationPageState extends State<CheckLocationPage> {
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
  String? scheduleIn;
  String? scheduleOut;
  bool hasCheckedInToday = false;
  Position? currentPosition;
  double? officeLat;
  double? officeLong;
  MapController mapController = MapController();
  String currentTileLayer = 'openstreetmap';
  String? currentAddress;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  // Ganti di loadUserData() CheckLocationPage:
  Future<void> loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // AMBIL EMPID BUKAN USERID!
    setState(() {
      employeeId = prefs.getString("empid") ?? ""; // ← GUNAKAN empid
      employeeName =
          prefs.getString("empname") ?? ""; // ← empname bukan username
      employeeNik = prefs.getString("nik") ?? "";
      locationId = prefs.getString("locationid") ?? "";
    });

    await loadHomeData();
    await checkLocationAccess();
  }

  Future<void> loadHomeData() async {
    try {
      final response = await http.get(
        Uri.parse(
            "http://192.168.0.151:8000/api/new_gethomedata?employeeid=$employeeId&date=${DateFormat('yyyy-MM-dd').format(DateTime.now())}"),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          setState(() {
            attendanceData = result['data']['attendance'];
            // ...
          });
        }
      }
    } catch (e) {}
  }

  Future<void> checkLocationAccess() async {
    setState(() {
      isLoading = true;
      status = "Checking...";
      distanceMeter = null;
      locationData = null;
      canCheckInOut = false;
      currentPosition = null;
      officeLat = null;
      officeLong = null;
    });

    if (locationId == null || locationId!.isEmpty) {
      setState(() {
        status = "LocationID tidak ditemukan!";
        isLoading = false;
      });
      return;
    }

    bool success = await fetchLocationFromAPI(locationId!);
    if (!success) return;

    if (!await _handleLocationPermission()) return;

    try {
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      await _getAddressFromLatLng(currentPosition!);
    } catch (e) {
      setState(() {
        status = "Gagal mendapatkan posisi GPS: $e";
        isLoading = false;
      });
      return;
    }

    // Parse koordinat kantor
    try {
      officeLat = double.parse(locationData!["lat"].toString());
      officeLong = double.parse(locationData!["long"].toString());
    } catch (e) {
      setState(() {
        status = "Koordinat lokasi tidak valid: $e";
        isLoading = false;
      });
      return;
    }

    double radius =
        double.tryParse((locationData!["radius"] ?? 100).toString()) ?? 100.0;

    distanceMeter = Geolocator.distanceBetween(currentPosition!.latitude,
        currentPosition!.longitude, officeLat!, officeLong!);

    canCheckInOut = distanceMeter! <= radius;
    status = canCheckInOut ? "✔ BERADA DALAM LOKASI" : "❌ DI LUAR LOKASI";

    setState(() {
      isLoading = false;
    });
  }

  Future<bool> fetchLocationFromAPI(String locationId) async {
    final url = "http://192.168.0.151:8000/api/getlocationbyid?id=$locationId";
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final result = jsonDecode(res.body);

        if (result['success'] == true &&
            result['data'] is List &&
            result['data'].isNotEmpty) {
          locationData = Map<String, dynamic>.from(result['data'][0]);
          return true;
        } else {
          setState(() {
            status = "Data lokasi tidak ditemukan!";
            isLoading = false;
          });
          return false;
        }
      } else {
        setState(() {
          status = "Gagal memuat lokasi! Status: ${res.statusCode}";
          isLoading = false;
        });
        return false;
      }
    } catch (e) {
      setState(() {
        status = "Error fetch lokasi: $e";
        isLoading = false;
      });
      return false;
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        status = 'Location services are disabled.';
        isLoading = false;
      });
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          status = 'Location permissions are denied';
          isLoading = false;
        });
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        status = 'Location permissions are permanently denied.';
        isLoading = false;
      });
      return false;
    }

    return true;
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        setState(() {
          currentAddress = [
            place.street,
            place.subLocality, // kelurahan
            place.locality, // kecamatan / kota
            place.subAdministrativeArea, // kabupaten
            place.administrativeArea, // provinsi
            place.postalCode,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
        });
      }
    } catch (e) {
      currentAddress = "Gagal mengambil alamat";
      debugPrint("Reverse geocoding error: $e");
    }
  }

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
      'employeeId': employeeId!, // Ini empid
      'employeeName': employeeName!,
      'attendanceId': attendanceId,
      'locationData': locationData!,
      'currentPosition': currentPosition!,
      'canCheckInOut': canCheckInOut,
    });
  }

  // ====== HELPER TAMPILAN ======
  Color get _statusColor => canCheckInOut ? _kOk : _kBad;

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
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
  }

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
              Text(
                "Memuat peta...",
                style: TextStyle(color: _kMuted),
              ),
            ],
          ),
        ),
      );
    }

    final officePoint = LatLng(officeLat!, officeLong!);
    final userPoint =
        LatLng(currentPosition!.latitude, currentPosition!.longitude);

    // Radius asli untuk perhitungan jarak (100 meter)
    double actualRadius =
        double.tryParse((locationData!["radius"] ?? 100).toString()) ?? 100.0;

    // Ukuran lingkaran tetap dalam pixel (TIDAK BERUBAH SAAT ZOOM)
    const double circleRadiusInPixels = 40.0;

    // Pilih tile layer
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

    // Zoom level FIXED - TIDAK BISA DI ZOOM
    const double fixedZoomLevel = 16.0;

    // Nonaktifkan semua interaksi zoom
    const int interactiveFlags = InteractiveFlag.drag | // Hanya bisa drag
        InteractiveFlag.pinchZoom; // Biarkan pinch zoom tapi dengan batasan

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
                maxZoom: fixedZoomLevel, // Maksimum zoom = zoom tetap
                minZoom: fixedZoomLevel, // Minimum zoom = zoom tetap
                interactiveFlags: interactiveFlags,
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: 'com.yourcompany.yourapp',
                  tileProvider: NetworkTileProvider(),
                  backgroundColor: _kBlueLight,
                ),
                // Lingkaran radius FIXED (tidak berubah ukuran)
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
                // Garis penghubung
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [officePoint, userPoint],
                      color: _statusColor,
                      strokeWidth: 3.0,
                    ),
                  ],
                ),
                // Marker titik kantor dan user
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
            // Informasi radius di pojok
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
                        locationData?["locationname"] ?? "Head Office",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _kNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                if (locationData?["address"] != null &&
                    locationData!["address"].toString().isNotEmpty)
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
                      style: TextStyle(
                        fontSize: 11,
                        color: _kMuted,
                      ),
                    ),
                    Text(
                      "${locationData?["radius"]?.toString() ?? '100'} m",
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
          if (!canCheckInOut && distanceMeter != null && locationData != null)
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
                      "${(distanceMeter! - double.parse(locationData!["radius"]?.toString() ?? '100')).toStringAsFixed(2)} m di luar radius",
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
                await loadHomeData();
                await checkLocationAccess();
              },
            ),
          ],
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _kBlue),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: [
                  _buildStatusBanner(),
                  const SizedBox(height: 16),
                  _buildMapPreview(),
                  _buildLocationDetails(),
                  Container(
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
                                "${officeLat?.toStringAsFixed(6)}\n${officeLong?.toStringAsFixed(6)}",
                                Icons.business,
                                _kBlue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildCoordinateItem(
                                "Anda",
                                "${currentPosition?.latitude.toStringAsFixed(6)}\n${currentPosition?.longitude.toStringAsFixed(6)}",
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
                              border:
                                  Border.all(color: _kBlue.withOpacity(0.2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.place,
                                    color: _kBlue, size: 18),
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

                        // Tombol untuk lanjut ke camera
                        _buildActionButton(
                          label: widget.isCheckIn
                              ? "LANJUT KE CHECK IN"
                              : "LANJUT KE CHECK OUT",
                          icon: widget.isCheckIn ? Icons.login : Icons.logout,
                          colors: widget.isCheckIn
                              ? const [_kBlue, _kBlueSoft]
                              : const [_kNavy, _kBlue],
                        ),

                        // Tombol khusus untuk Check Out jika di luar radius
                        if (!canCheckInOut &&
                            !widget.isCheckIn &&
                            hasCheckedInToday)
                          _buildActionButton(
                            label: "CHECK OUT (DI LUAR RADIUS)",
                            icon: Icons.logout,
                            colors: const [Color(0xFFB91C1C), _kBad],
                          ),

                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ])));
  }
}
