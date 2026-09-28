import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

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

    print("=== DEBUG USER DATA (CheckLocationPage) ===");
    print("empid dari SharedPreferences: $employeeId");
    print("empname: $employeeName");
    print("nik: $employeeNik");
    print("locationid: $locationId");
    print("==========================================");

    await loadHomeData();
    await checkLocationAccess();
  }

  Future<void> loadHomeData() async {
    try {
      print("=== LOAD HOME DATA ===");
      print(
          "URL: http://localhost:8000/api/new_gethomedata?employeeid=$employeeId");

      final response = await http.get(
        Uri.parse(
            "http://localhost:8000/api/new_gethomedata?employeeid=$employeeId&date=${DateFormat('yyyy-MM-dd').format(DateTime.now())}"),
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
    } catch (e) {
      print("Error loading home data: $e");
    }
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
    final url = "http://localhost:8000/api/getlocationbyid?id=$locationId";
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

  // Di CheckLocationPage, ubah method _navigateToCameraPage:
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

    // Debug sebelum kirim data
    print("=== SENDING TO CAMERA ===");
    print("employeeId (empid): $employeeId");
    print("employeeName: $employeeName");
    print("isCheckIn: ${widget.isCheckIn}");
    print("==========================");

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

  Widget _buildMapPreview() {
    if (officeLat == null || officeLong == null || currentPosition == null) {
      return Container(
        height: 250,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                "Memuat peta...",
                style: TextStyle(color: Colors.grey),
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
      height: 280,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                  backgroundColor: Colors.blue,
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
                            color: canCheckInOut
                                ? Colors.green.withOpacity(0.15)
                                : Colors.red.withOpacity(0.15),
                            border: Border.all(
                              color: canCheckInOut ? Colors.green : Colors.red,
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
                      color: canCheckInOut ? Colors.green : Colors.red,
                      strokeWidth: 2.0,
                    ),
                  ],
                ),
                // Marker titik kantor dan user
                MarkerLayer(
                  markers: [
                    Marker(
                      point: officePoint,
                      width: 40,
                      height: 40,
                      builder: (ctx) => Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 5,
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
                      width: 40,
                      height: 40,
                      builder: (ctx) => Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: canCheckInOut ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
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
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  "Radius: ${actualRadius.toStringAsFixed(0)} m",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: canCheckInOut ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 5,
                    ),
                  ],
                ),
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
              bottom: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text("Kantor", style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 10),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: canCheckInOut ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text("Anda", style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Text(
                  "${distanceMeter?.toStringAsFixed(2) ?? '0.00'} m",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: canCheckInOut ? Colors.green : Colors.red,
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
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📍 Detail Lokasi",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.business, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locationData?["locationname"] ?? "Head Office",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (locationData?["address"] != null &&
              locationData!["address"].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locationData!["address"].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: canCheckInOut
                  ? Colors.green.withOpacity(0.05)
                  : Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: canCheckInOut ? Colors.green : Colors.red,
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
                          color: canCheckInOut ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          canCheckInOut ? "Dalam Radius" : "Luar Radius",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: canCheckInOut ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (distanceMeter != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 24),
                        child: Text(
                          "Jarak: ${distanceMeter!.toStringAsFixed(2)} m",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Radius:",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "${locationData?["radius"]?.toString() ?? '100'} m",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${(distanceMeter! - double.parse(locationData!["radius"]?.toString() ?? '100')).toStringAsFixed(2)} m di luar radius",
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 12,
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  coordinate,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.isCheckIn ? "Check In" : "Check Out"),
          backgroundColor: Colors.blue[700],
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () async {
                await loadHomeData();
                await checkLocationAccess();
              },
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: canCheckInOut
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: canCheckInOut ? Colors.green : Colors.red,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          canCheckInOut ? Icons.check_circle : Icons.cancel,
                          color: canCheckInOut ? Colors.green : Colors.red,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      canCheckInOut ? Colors.green : Colors.red,
                                ),
                              ),
                              if (distanceMeter != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    "Jarak: ${distanceMeter!.toStringAsFixed(2)} meter",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMapPreview(),
                  _buildLocationDetails(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "📍 Koordinat",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCoordinateItem(
                                "Kantor",
                                "${officeLat?.toStringAsFixed(6)}\n${officeLong?.toStringAsFixed(6)}",
                                Icons.business,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildCoordinateItem(
                                "Anda",
                                "${currentPosition?.latitude.toStringAsFixed(6)}\n${currentPosition?.longitude.toStringAsFixed(6)}",
                                Icons.person_pin_circle,
                                canCheckInOut ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        if (currentAddress != null)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.place,
                                    color: Colors.blue, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    currentAddress!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Tombol untuk lanjut ke camera
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ElevatedButton(
                            onPressed: _navigateToCameraPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.isCheckIn
                                  ? Colors.green
                                  : Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.isCheckIn ? Icons.login : Icons.logout,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.isCheckIn
                                      ? "LANJUT KE CHECK IN"
                                      : "LANJUT KE CHECK OUT",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Tombol khusus untuk Check Out jika di luar radius
                        if (!canCheckInOut &&
                            !widget.isCheckIn &&
                            hasCheckedInToday)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ElevatedButton(
                              onPressed: _navigateToCameraPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.logout,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "CHECK OUT (DI LUAR RADIUS)",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ])));
  }
}
