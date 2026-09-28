import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'succes_screen.dart';

class CameraPage extends StatefulWidget {
  final bool isCheckIn;
  final String employeeId;
  final String employeeName;
  final String? attendanceId;
  final Map<String, dynamic> locationData;
  final Position currentPosition;
  final bool canCheckInOut;

  const CameraPage({
    super.key,
    required this.isCheckIn,
    required this.employeeId,
    required this.employeeName,
    this.attendanceId,
    required this.locationData,
    required this.currentPosition,
    required this.canCheckInOut,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? controller;
  bool isCameraReady = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    initCam();
  }

  Future<void> initCam() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller!.initialize();

      if (!mounted) return;

      setState(() => isCameraReady = true);
    } catch (e) {
      print("Error initializing camera: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error kamera: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> takePicture() async {
    if (!controller!.value.isInitialized || isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final image = await controller!.takePicture();
      final imageFile = File(image.path);

      // Konversi gambar ke base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Panggil API check in/out
      if (widget.isCheckIn) {
        await _checkIn(base64Image);
      } else {
        await _checkOut(base64Image);
      }
    } catch (e) {
      print("Error taking picture: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _checkIn(String base64Image) async {
    try {
      print("=== CHECK IN API CALL ===");
      print("employeeId (empid): ${widget.employeeId}"); // Ini harus 1984

      String now = DateFormat('HH:mm:ss').format(DateTime.now());
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String requestTime = DateTime.now().toIso8601String();

      String attendanceStatus =
          widget.canCheckInOut ? "Present" : "Waiting Approval";
      String description = widget.canCheckInOut
          ? "Check In dalam area lokasi"
          : "Check In di luar area lokasi - memerlukan persetujuan";

      final response = await http.post(
        Uri.parse("http://localhost:8000/api/new_clockin"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": widget.attendanceId,
          "employeeid": widget.employeeId, // ← INI EMPID
          "employeename": widget.employeeName,
          "date": today,
          "checkin": now,
          "createdby": widget.employeeName,
          "createddate": requestTime,
          "status": attendanceStatus,
          "ext": "jpg",
          "data": base64Image,
          "locationsettingname":
              widget.locationData["locationname"] ?? "Head Office",
          "locationaddress": widget.locationData["address"] ?? "",
          "locationcoordinate":
              "${widget.currentPosition.latitude},${widget.currentPosition.longitude}",
          "description": description,
          "requesttime": requestTime,
        }),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
// Di dalam _checkIn() setelah result['success'] == true:
        if (result['success'] == true) {
          // Navigasi ke success screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => SuccessScreen(
                title: "Check In Berhasil!",
                message: "Anda telah berhasil melakukan check in.",
                employeeName: widget.employeeName,
                time: now,
                isCheckIn: true,
                needsApproval: !widget.canCheckInOut,
                employeeId: widget.employeeId, // TAMBAHKAN INI
                employeeNameParam: widget.employeeName, // TAMBAHKAN INI
              ),
            ),
            (route) => false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Check In berhasil"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.popUntil(context, (route) => route.isFirst);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Check In gagal"),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            isLoading = false;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Check In gagal: ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _checkOut(String base64Image) async {
    try {
      String now = DateFormat('HH:mm:ss').format(DateTime.now());
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String requestTime = DateTime.now().toIso8601String();

      String attendanceStatus =
          widget.canCheckInOut ? "Present" : "Waiting Approval";
      String description = widget.canCheckInOut
          ? "Check Out dalam area lokasi"
          : "Check Out di luar area lokasi - memerlukan persetujuan";

      final response = await http.post(
        Uri.parse("http://localhost:8000/api/new_clockout"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": widget.attendanceId,
          "employeeid": widget.employeeId,
          "date": today,
          "checkout": now,
          "createdby": widget.employeeName,
          "createddate": requestTime,
          "status": attendanceStatus,
          "ext": "jpg",
          "data": base64Image,
          "locationsettingname":
              widget.locationData["locationname"] ?? "Head Office",
          "locationaddress": widget.locationData["address"] ?? "",
          "locationcoordinate":
              "${widget.currentPosition.latitude},${widget.currentPosition.longitude}",
          "description": description,
          "requesttime": requestTime,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
// Di dalam _checkOut() setelah result['success'] == true:
        if (result['success'] == true) {
          // Navigasi ke success screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => SuccessScreen(
                title: "Check Out Berhasil!",
                message: "Anda telah berhasil melakukan check out.",
                employeeName: widget.employeeName,
                time: now,
                isCheckIn: false,
                needsApproval: !widget.canCheckInOut,
                employeeId: widget.employeeId, // TAMBAHKAN INI
                employeeNameParam: widget.employeeName, // TAMBAHKAN INI
              ),
            ),
            (route) => false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Check Out berhasil"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.popUntil(context, (route) => route.isFirst);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Check Out gagal"),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            isLoading = false;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Check Out gagal: ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isCheckIn ? "Check In" : "Check Out",
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          if (!isCameraReady || isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (isCameraReady && !isLoading) CameraPreview(controller!),
          Positioned(
            top: 40,
            child: Column(
              children: [
                Text(
                  widget.isCheckIn ? "CHECK IN" : "CHECK OUT",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isCheckIn
                      ? "Ambil foto untuk Check In"
                      : "Ambil foto untuk Check Out",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Positioned(
            top: 120,
            child: Column(
              children: const [
                Text(
                  "Align your face with the frame",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Posisikan wajah Anda dalam lingkaran.",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Positioned(
            child: Container(
              width: 260,
              height: 360,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(180),
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 3,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            child: GestureDetector(
              onTap: isLoading ? null : takePicture,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isLoading ? Colors.grey : Colors.transparent,
                  border: Border.all(color: Colors.white, width: 4),
                  shape: BoxShape.circle,
                ),
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 40,
                      ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.canCheckInOut ? "✓ Dalam Radius" : "⚠ Perlu Persetujuan",
                style: TextStyle(
                  color: widget.canCheckInOut ? Colors.green : Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
