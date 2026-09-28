import 'package:flutter/material.dart';
import 'attendance_log_screen.dart';
import 'attendance_home.dart';

class SuccessScreen extends StatelessWidget {
  final String title;
  final String message;
  final String? employeeName;
  final String time;
  final bool isCheckIn;
  final bool needsApproval;
  final String employeeId; // Tambahkan ini
  final String employeeNameParam; // Tambahkan ini

  const SuccessScreen({
    super.key,
    required this.title,
    required this.message,
    this.employeeName,
    required this.time,
    required this.isCheckIn,
    this.needsApproval = false,
    required this.employeeId, // Tambahkan ini
    required this.employeeNameParam, // Tambahkan ini
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Success
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: needsApproval ? Colors.orange[50] : Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    needsApproval ? Icons.pending_actions : Icons.check_circle,
                    size: 64,
                    color: needsApproval ? Colors.orange : Colors.green,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                needsApproval ? "Menunggu Persetujuan" : title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: needsApproval ? Colors.orange[700] : Colors.green[700],
                ),
              ),

              const SizedBox(height: 16),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 40),

              // Detail Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey),
                ),
                child: Column(
                  children: [
                    if (employeeName != null)
                      _buildDetailRow("Nama Karyawan", employeeName!),
                    _buildDetailRow(
                      isCheckIn ? "Clock In" : "Clock Out",
                      time,
                    ),
                    _buildDetailRow(
                      "Tanggal",
                      "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                    ),
                    _buildDetailRow(
                      "Status",
                      needsApproval ? "Menunggu Persetujuan" : "Berhasil",
                      valueColor: needsApproval ? Colors.orange : Colors.green,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Buttons
              Column(
                children: [
                  // Button Lihat Log Absensi
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigasi ke log absensi dengan parameter yang benar
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AttendanceLogScreen(
                              employeeId:
                                  employeeId, // Gunakan parameter yang sudah diterima
                              employeeName:
                                  employeeNameParam, // Gunakan parameter yang sudah diterima
                            ),
                          ),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Lihat Log Absensi",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Button Kembali ke Beranda
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const HomePage()),
                          (route) => false, // hapus semua stack
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.blue),
                      ),
                      child: const Text(
                        "Kembali ke Beranda",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Tips
              if (needsApproval)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Absensi Anda akan diperiksa oleh admin. "
                    "Anda dapat mengecek statusnya di halaman log absensi.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
