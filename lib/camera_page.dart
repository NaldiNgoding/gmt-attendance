import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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

  // ── ML Kit face detector ─────────────────────────────────────────────────
  FaceDetector? _faceDetector;
  bool _processingFrame = false;
  bool _faceDetected = false;
  DateTime _lastFrameTime = DateTime.now();

  // ── Platform helper ─────────────────────────────────────────────────────
  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();

    if (_isMobile) {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableLandmarks: false,
          enableClassification: false,
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.05, // longgar — deteksi wajah kecil sekalipun
        ),
      );
    }

    initCam();
  }

  @override
  void dispose() {
    if (_isMobile && controller?.value.isInitialized == true) {
      controller?.stopImageStream().catchError((_) {});
    }
    controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INIT CAMERA
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> initCam() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('Tidak ada kamera yang tersedia');
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      ImageFormatGroup format;
      if (kIsWeb) {
        format = ImageFormatGroup.jpeg;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        format = ImageFormatGroup.nv21;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        format = ImageFormatGroup.bgra8888;
      } else {
        format = ImageFormatGroup.unknown;
      }

      controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: format,
      );

      await controller!.initialize();

      if (!mounted) return;

      if (_isMobile) {
        controller!.startImageStream(_processCameraImage);
      } else {
        // Web/Desktop: skip face detection
        _faceDetected = true;
      }

      setState(() => isCameraReady = true);
    } catch (e, st) {
      debugPrint("Error initializing camera: $e\n$st");
      if (!mounted) return;

      setState(() {
        if (kIsWeb) _faceDetected = true;
        isCameraReady = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error kamera: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FACE DETECTION — Longgar, cuma cek ADA wajah
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _processCameraImage(CameraImage image) async {
    if (!_isMobile || _faceDetector == null) return;

    // Throttle ~5 fps
    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < 200) return;
    if (_processingFrame) return;

    _processingFrame = true;
    _lastFrameTime = now;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) {
        _processingFrame = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);

      // Validasi minimal: ADA minimal 1 wajah
      final bool detected = faces.isNotEmpty;

      debugPrint("[Face] detected=$detected, count=${faces.length}");

      if (!mounted) {
        _processingFrame = false;
        return;
      }

      if (detected != _faceDetected) {
        setState(() => _faceDetected = detected);
      }
    } catch (e) {
      debugPrint("Face detection error: $e");
      if (mounted && _faceDetected) {
        setState(() => _faceDetected = false);
      }
    } finally {
      _processingFrame = false;
    }
  }

  /// Konversi CameraImage → InputImage untuk ML Kit
  InputImage? _toInputImage(CameraImage image) {
    if (!_isMobile) return null;

    final camera = controller?.description;
    if (camera == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      int rotationCompensation = 0;
      final deviceOrientation = controller!.value.deviceOrientation;
      switch (deviceOrientation) {
        case DeviceOrientation.portraitUp:
          rotationCompensation = 0;
          break;
        case DeviceOrientation.landscapeLeft:
          rotationCompensation = 90;
          break;
        case DeviceOrientation.portraitDown:
          rotationCompensation = 180;
          break;
        case DeviceOrientation.landscapeRight:
          rotationCompensation = 270;
          break;
      }
      final rotationComp = (sensorOrientation + rotationCompensation) % 360;
      rotation = InputImageRotationValue.fromRawValue(rotationComp);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAKE PICTURE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> takePicture() async {
    if (controller == null || !controller!.value.isInitialized || isLoading) {
      return;
    }

    // Validasi: hanya cek wajah terdeteksi (mobile)
    if (_isMobile && !_faceDetected) {
      _showWarning('Wajah tidak terdeteksi. Posisikan wajah di dalam frame.');
      return;
    }

    setState(() => isLoading = true);

    try {
      if (_isMobile && controller!.value.isStreamingImages) {
        await controller!.stopImageStream();
      }

      final XFile image = await controller!.takePicture();
      final bytes = await image.readAsBytes();

      // Re-validate foto hasil (mobile) — longgar
      if (_isMobile && _faceDetector != null) {
        final inputImage = InputImage.fromFilePath(image.path);
        final faces = await _faceDetector!.processImage(inputImage);

        if (faces.isEmpty) {
          if (!mounted) return;
          _showWarning('Tidak ada wajah di foto. Coba lagi.');
          setState(() => isLoading = false);
          _restartStream();
          return;
        }
        // Kalau ada wajah (walau > 1), lanjut aja
      }

      final base64Image = base64Encode(bytes);

      if (widget.isCheckIn) {
        await _checkIn(base64Image);
      } else {
        await _checkOut(base64Image);
      }
    } catch (e, st) {
      debugPrint("Error taking picture: $e\n$st");
      if (!mounted) return;
      _showError("Error: $e");
      setState(() => isLoading = false);
      _restartStream();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  API CALLS
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _checkIn(String base64Image) async {
    try {
      final now = DateFormat('HH:mm:ss').format(DateTime.now());
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final requestTime = DateTime.now().toIso8601String();

      final attendanceStatus =
          widget.canCheckInOut ? "Present" : "Waiting Approval";
      final description = widget.canCheckInOut
          ? "Check In dalam area lokasi"
          : "Check In di luar area lokasi - memerlukan persetujuan";

      final response = await http.post(
        Uri.parse("http://192.168.0.151:8000/api/new_clockin"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": widget.attendanceId,
          "employeeid": widget.employeeId,
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

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          _navigateToSuccess(
            title: "Check In Berhasil!",
            message: "Anda telah berhasil melakukan check in.",
            time: now,
            isCheckIn: true,
          );
        } else {
          _showError(result['message'] ?? "Check In gagal");
          setState(() => isLoading = false);
          _restartStream();
        }
      } else {
        _showError("Check In gagal: ${response.body}");
        setState(() => isLoading = false);
        _restartStream();
      }
    } catch (e) {
      _showError("Error: $e");
      setState(() => isLoading = false);
      _restartStream();
    }
  }

  Future<void> _checkOut(String base64Image) async {
    try {
      final now = DateFormat('HH:mm:ss').format(DateTime.now());
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final requestTime = DateTime.now().toIso8601String();

      final attendanceStatus =
          widget.canCheckInOut ? "Present" : "Waiting Approval";
      final description = widget.canCheckInOut
          ? "Check Out dalam area lokasi"
          : "Check Out di luar area lokasi - memerlukan persetujuan";

      final response = await http.post(
        Uri.parse("http://192.168.0.151:8000/api/new_clockout"),
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

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          _navigateToSuccess(
            title: "Check Out Berhasil!",
            message: "Anda telah berhasil melakukan check out.",
            time: now,
            isCheckIn: false,
          );
        } else {
          _showError(result['message'] ?? "Check Out gagal");
          setState(() => isLoading = false);
          _restartStream();
        }
      } else {
        _showError("Check Out gagal: ${response.body}");
        setState(() => isLoading = false);
        _restartStream();
      }
    } catch (e) {
      _showError("Error: $e");
      setState(() => isLoading = false);
      _restartStream();
    }
  }

  void _navigateToSuccess({
    required String title,
    required String message,
    required String time,
    required bool isCheckIn,
  }) {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => SuccessScreen(
          title: title,
          message: message,
          employeeName: widget.employeeName,
          time: time,
          isCheckIn: isCheckIn,
          needsApproval: !widget.canCheckInOut,
          employeeId: widget.employeeId,
          employeeNameParam: widget.employeeName,
        ),
      ),
      (route) => false,
    );
  }

  void _restartStream() {
    if (_isMobile && controller?.value.isInitialized == true) {
      try {
        controller!.startImageStream(_processCameraImage);
      } catch (e) {
        debugPrint("Restart stream error: $e");
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showWarning(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UI HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  Color get _frameColor {
    return _faceDetected ? Colors.green : Colors.white.withValues(alpha: 0.5);
  }

  String get _faceHint {
    if (kIsWeb) return 'Posisikan wajah di dalam frame';
    if (_faceDetected) return 'Wajah terdeteksi. Tekan tombol untuk foto.';
    return 'Posisikan wajah di dalam frame';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
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
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          if (isCameraReady && !isLoading && controller != null)
            CameraPreview(controller!),

          // Judul
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

          // Hint
          Positioned(
            top: 120,
            child: Column(
              children: [
                const Text(
                  "Align your face with the frame",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _faceHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _faceDetected ? Colors.greenAccent : Colors.white70,
                    fontWeight:
                        _faceDetected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

          // Frame oval
          Positioned(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 260,
              height: 360,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(180),
                border: Border.all(
                  color: _frameColor,
                  width: _faceDetected ? 4 : 3,
                ),
                boxShadow: _faceDetected
                    ? [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),

          // Status badge
          Positioned(
            bottom: 120,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _faceDetected
                        ? Icons.check_circle
                        : Icons.face_retouching_natural,
                    color: _faceDetected ? Colors.green : Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _faceDetected ? "Wajah OK" : "Mencari wajah...",
                    style: TextStyle(
                      color: _faceDetected ? Colors.green : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tombol shutter
          Positioned(
            bottom: 40,
            child: GestureDetector(
              onTap: (isLoading || !_faceDetected || !isCameraReady)
                  ? null
                  : takePicture,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: (isLoading || !_faceDetected)
                      ? Colors.grey.withValues(alpha: 0.5)
                      : Colors.transparent,
                  border: Border.all(
                    color: _faceDetected ? Colors.green : Colors.white,
                    width: 4,
                  ),
                  shape: BoxShape.circle,
                ),
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Icon(
                        Icons.camera_alt,
                        color: _faceDetected ? Colors.green : Colors.white,
                        size: 40,
                      ),
              ),
            ),
          ),

          // Radius badge
          Positioned(
            bottom: 130,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.canCheckInOut ? "✓ Dalam Radius" : "⚠ Perlu Persetujuan",
                style: TextStyle(
                  color: widget.canCheckInOut ? Colors.green : Colors.orange,
                  fontSize: 12,
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
