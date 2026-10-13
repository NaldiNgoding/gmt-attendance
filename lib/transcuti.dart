import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TransCutiPage extends StatefulWidget {
  final String employeeId;
  final int initialYear;
  final String baseUrl;

  const TransCutiPage({
    super.key,
    required this.employeeId,
    required this.initialYear,
    required this.baseUrl,
  });

  @override
  State<TransCutiPage> createState() => _TransCutiPageState();
}

class _TransCutiPageState extends State<TransCutiPage> {
  static const Color kNavy = Color(0xFF0D47A1);

  late int _selectedYear;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  bool _balanceExpanded = false;
  bool _takenExpanded = false;
  bool _takenCarryExpanded = false;
  bool _takenBalanceExpanded = false;
  bool _adjustmentExpanded = false;

  double _number(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  double get _balance => _number(_data['balance']);
  double get _adjustmentBalance => _number(_data['adjustment_balance']);
  double get _carryForwardBalance => _number(
      _data['carryforward_balance'] ?? _netTransactionQty(_carryForward));
  double get _takenBalance =>
      _number(_data['taken_balance'] ?? _netTransactionQty(_taken));
  double get _expiredBalance => _number(_data['expired_balance']);
  double get _nextYearTaken => _number(_data['next_year_taken']);
  double get _detailRemainingBalance =>
      _balance +
      _carryForwardBalance +
      _takenBalance +
      _adjustmentBalance -
      _expiredBalance;

  bool _isCarryTransaction(Map<String, dynamic> item) {
    return (item['sub_taken_from']?.toString().toLowerCase() ?? '') == 'carry';
  }

  List<Map<String, dynamic>> get _takenFromCarryTransactions =>
      _taken.where(_isCarryTransaction).toList();

  List<Map<String, dynamic>> get _takenFromBalanceTransactions =>
      _taken.where((item) => !_isCarryTransaction(item)).toList();

  double _sumTransactionQty(
    List<Map<String, dynamic>> transactions,
  ) {
    return transactions.fold<double>(
      0,
      (total, item) => total + _number(item['qty'] ?? item['quantity']).abs(),
    );
  }

  double get _takenFromCarryTotal =>
      _sumTransactionQty(_takenFromCarryTransactions);

  double get _takenFromBalanceTotal =>
      _sumTransactionQty(_takenFromBalanceTransactions);

  List<Map<String, dynamic>> get _adjustments =>
      _asMapList(_data['adjustments']);

  List<Map<String, dynamic>> get _carryForward =>
      _asMapList(_data['carryforward']);

  double _netTransactionQty(
    List<Map<String, dynamic>> transactions,
  ) {
    return transactions.fold<double>(0, (total, item) {
      final qty = _number(item['qty'] ?? item['quantity']).abs();
      final changeType = item['change_type']?.toString().toLowerCase().trim();

      if (changeType == 'add') return total + qty;
      if (changeType == 'sub') return total - qty;

      return total;
    });
  }

  List<Map<String, dynamic>> get _taken => _asMapList(_data['taken']);

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '${widget.baseUrl}/gettranscutibyyearempid',
      ).replace(
        queryParameters: {
          'year': _selectedYear.toString(),
          'empid': widget.employeeId,
        },
      );

      final response = await http.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}: gagal mengambil transaksi cuti.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map || decoded['success'] != true) {
        throw Exception(
          decoded is Map
              ? decoded['message']?.toString() ??
                  'Gagal mengambil transaksi cuti.'
              : 'Format response API tidak sesuai.',
        );
      }

      final rawData = decoded['data'];

      if (rawData is! Map) {
        throw Exception('Data transaksi cuti tidak ditemukan.');
      }

      if (!mounted) return;

      setState(() {
        _data = Map<String, dynamic>.from(rawData);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Widget _buildTopPanel() {
    final years = <int>{
      _selectedYear,
      ...List.generate(
        5,
        (index) => DateTime.now().year - index,
      ),
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 11, 66, 154),
            Color.fromARGB(255, 15, 92, 207),
            Color(0xFF1E88E5),
          ],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 8,
        20,
        24,
      ),
      child: Column(
        children: [
          // HEADER: tombol Back dan judul halaman
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                  },
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'Cuti Karyawan/ti Tahunan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),

          const SizedBox(height: 20),

          // KARTU REMAINING BALANCE DAN TAKEN
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Remaining Balance',
                  value: _formatDays(_detailRemainingBalance),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Taken',
                  value: _formatDays(_takenBalance.abs()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // DROPDOWN TAHUN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedYear,
                isExpanded: true,
                items: years.map((year) {
                  return DropdownMenuItem<int>(
                    value: year,
                    child: Text(
                      year.toString(),
                      style: const TextStyle(
                        color: Color(0xFF252525),
                        fontSize: 18,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (year) async {
                  if (year == null || year == _selectedYear) {
                    return;
                  }
                  setState(() {
                    _selectedYear = year;
                  });
                  await _loadTransactions();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Color(0xFF252525),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF252525),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDays(double value) {
    final number = value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);

    return '$number ${value.abs() == 1 ? 'day' : 'days'}';
  }

  Widget _buildAnimatedExpansion({
    required bool expanded,
    required Widget child,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: double.infinity,
        child: expanded ? child : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBalanceSection() {
    return Column(
      children: [
        _buildSectionHeader(
          title: 'Balance',
          amount: _formatDays(_balance),
          expanded: _balanceExpanded,
          onTap: () {
            setState(() {
              _balanceExpanded = !_balanceExpanded;
            });
          },
        ),
        _buildAnimatedExpansion(
          expanded: _balanceExpanded,
          child: Column(
            children: [
              _buildDetailRow(
                  title: 'Beginning',
                  amount: _formatDays(_balance),
                  titleColor: Colors.green.shade700),
              _buildDetailRow(
                  title: 'Carry forward',
                  amount: _formatDays(_carryForwardBalance),
                  titleColor: Colors.green.shade700),
              _buildDetailRow(
                  title: 'Expired',
                  amount: _formatDays(_expiredBalance),
                  titleColor: Colors.red.shade600),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTakenSection() {
    return Column(
      children: [
        _buildSectionHeader(
          title: 'Taken',
          amount: _formatDays(_takenBalance),
          expanded: _takenExpanded,
          onTap: () {
            setState(() {
              _takenExpanded = !_takenExpanded;
            });
          },
        ),
        _buildAnimatedExpansion(
          expanded: _takenExpanded,
          child: Column(
            children: [
              // Taken from Carry
              _buildSectionHeader(
                title: 'Taken from Carry',
                amount: _formatDays(_takenFromCarryTotal),
                expanded: _takenCarryExpanded,
                onTap: () {
                  setState(() {
                    _takenCarryExpanded = !_takenCarryExpanded;
                  });
                },
                compact: true,
              ),
              _buildAnimatedExpansion(
                expanded: _takenCarryExpanded,
                child: _buildTransactionList(
                  _takenFromCarryTransactions,
                ),
              ),
              // Taken from Balance
              _buildSectionHeader(
                title: 'Taken from Balance',
                amount: _formatDays(_takenFromBalanceTotal),
                expanded: _takenBalanceExpanded,
                onTap: () {
                  setState(() {
                    _takenBalanceExpanded = !_takenBalanceExpanded;
                  });
                },
                compact: true,
              ),
              _buildAnimatedExpansion(
                expanded: _takenBalanceExpanded,
                child: _buildTransactionList(
                  _takenFromBalanceTransactions,
                ),
              ),
              // Taken next year
              _buildDetailRow(
                title: 'Taken next year',
                amount: _formatDays(_nextYearTaken.abs()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdjustmentSection() {
    return Column(
      children: [
        _buildSectionHeader(
          title: 'Adjustment',
          amount: _formatDays(_adjustmentBalance),
          subtitle: '${_adjustments.length} transactions',
          expanded: _adjustmentExpanded,
          onTap: () {
            setState(() {
              _adjustmentExpanded = !_adjustmentExpanded;
            });
          },
        ),
        _buildAnimatedExpansion(
          expanded: _adjustmentExpanded,
          child: _buildTransactionList(_adjustments),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String amount,
    required bool expanded,
    required VoidCallback onTap,
    String? subtitle,
    bool compact = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: compact ? 14 : 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 14 : 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF252525),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                amount,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: compact ? 14 : 17,
                  color: const Color(0xFF252525),
                ),
              ),
            ),
            const SizedBox(width: 14),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: compact ? 25 : 34,
                color: const Color(0xFF252525),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String title,
    required String amount,
    Color? titleColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FBFD),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: titleColor ?? const Color(0xFF252525),
              ),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF252525),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(
    List<Map<String, dynamic>> transactions,
  ) {
    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        color: const Color(0xFFF4F7FA),
        child: Text(
          'Tidak ada transaksi.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return Column(
      children: transactions.map((item) {
        final date = item['date'];
        final qty = _number(item['qty']);
        final changeType = item['change_type']?.toString().toLowerCase() ?? '';

        final amount = changeType == 'sub'
            ? '-${_formatDays(qty.abs())}'
            : changeType == 'add'
                ? '+${_formatDays(qty.abs())}'
                : _formatDays(qty);

        final generatedBy = item['createdbyname']?.toString().trim() ?? '';
        final expiry = item['expireddate']?.toString().trim() ?? '';
        final description = item['description']?.toString().trim() ?? '';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F6F9),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _formatTransactionDate(date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (generatedBy.isNotEmpty || expiry.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  [
                    if (generatedBy.isNotEmpty) 'Generated by: $generatedBy',
                    if (expiry.isNotEmpty)
                      'Expired: ${_formatTransactionDate(expiry)}',
                  ].join(' | '),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  'Description: $description',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTransactionDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) return value.isEmpty ? '-' : value;

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final day = date.day.toString().padLeft(2, '0');

    return '$day ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Loading penuh hanya saat pertama kali membuka halaman.
          if (_isLoading && _data.isEmpty)
            const Center(
              child: CircularProgressIndicator(
                color: kNavy,
              ),
            )
          // 2. Error penuh hanya jika belum ada data yang bisa ditampilkan.
          else if (_error != null && _data.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadTransactions,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          // 3. Jika sudah ada data, pertahankan seluruh halaman
          else
            ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildTopPanel(),
                // Pesan jika pengambilan data tahun baru gagal.
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange.shade50,
                    child: Text(
                      'Gagal memperbarui data. Data sebelumnya '
                      'masih ditampilkan. $_error',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                _buildBalanceSection(),
                _buildTakenSection(),
                _buildAdjustmentSection(),
              ],
            ),
          // 4. Loading kecil ketika mengganti tahun.
          if (_isLoading && _data.isNotEmpty)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: Color(0xFF42A5F5),
                backgroundColor: Color(0xFFE3EAF5),
              ),
            ),
        ],
      ),
    );
  }
}
