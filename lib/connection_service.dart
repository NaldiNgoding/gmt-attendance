import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
enum ConnectionStatus {
  checking,
  good,
  weak,
  offline,
}

class ConnectionService {
  ConnectionService._();

  static final ConnectionService instance = ConnectionService._();

  final ValueNotifier<ConnectionStatus> status =
      ValueNotifier(ConnectionStatus.checking);

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;

  bool _started = false;
  bool _checking = false;
  int _failures = 0;

  // Ganti dengan URL API ping milik aplikasi.
  static const String pingUrl = 'http://localhost:8000/api/ping';

  void start() {
    if (_started) return;

    _started = true;

    // Pemeriksaan langsung ketika service dimulai.
    _check();

    // Periksa perubahan konektivitas.
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        _failures = 0;
        _setStatus(ConnectionStatus.offline);
      } else {
        _check();
      }
    });

    // Ping API setiap 1 menit.
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _check(),
    );
  }

  Future<void> _check() async {
    if (_checking) return;

    _checking = true;

    try {
      final response = await http.get(
        Uri.parse(pingUrl),
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _failures = 0;
        _setStatus(ConnectionStatus.good);
      } else {
        _handleFailure();
      }
    } catch (e) {
      debugPrint('[CONNECTION] Ping gagal: $e');
      _handleFailure();
    } finally {
      _checking = false;
    }
  }

  void _handleFailure() {
    _failures++;

    // Hindari salah deteksi karena satu request gagal.
    if (_failures >= 3 || status.value == ConnectionStatus.checking) {
      _setStatus(ConnectionStatus.offline);
    }
  }

  void _setStatus(ConnectionStatus newStatus) {
    if (status.value == newStatus) return;

    status.value = newStatus;

    debugPrint('[CONNECTION] Status: $newStatus');
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _subscription?.cancel();

    _timer = null;
    _subscription = null;
    _started = false;
  }
}
