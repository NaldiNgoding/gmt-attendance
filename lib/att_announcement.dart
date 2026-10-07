import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// ============================================================
// MODEL
// ============================================================

class Announcement {
  final int id;
  final String? date;
  final String? type;
  final String title;
  final String? header;
  final String? subheader;
  final String? body;
  final String? footer;
  final String? notes;
  final String? author;
  final String? filename;

  const Announcement({
    required this.id,
    this.date,
    this.type,
    required this.title,
    this.header,
    this.subheader,
    this.body,
    this.footer,
    this.notes,
    this.author,
    this.filename,
  });

  factory Announcement.fromJson(
    Map<String, dynamic> json,
  ) {
    return Announcement(
      id: int.tryParse(
            json['id']?.toString() ?? '',
          ) ??
          0,
      date: _clean(json['date']),
      type: _clean(json['type']),
      title: _clean(json['title']) ?? '',
      header: _clean(json['header']),
      subheader: _clean(json['subheader']),
      body: _clean(json['body']),
      footer: _clean(json['footer']),
      notes: _clean(json['notes']),
      author: _clean(json['author']),
      filename: _clean(json['filename']),
    );
  }

  static String? _clean(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}

// ============================================================
// SERVICE
// ============================================================

class AnnouncementService {
  static const String baseUrl = 'http://192.168.0.151:8000/api';

  Future<List<Announcement>> getAnnouncements() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/get-announcements',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded['success'] != true) {
      throw Exception(
        decoded['message'] ?? 'Gagal mengambil announcement',
      );
    }

    final rawData = decoded['data'];
    if (rawData is! List) {
      return [];
    }
    return rawData
        .map(
          (item) => Announcement.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  String getPreviewUrl(String filename) {
    return '$baseUrl/announcement-file/preview/'
        '${Uri.encodeComponent(filename)}';
  }

  String getDownloadUrl(String filename) {
    return '$baseUrl/announcement-file/download/'
        '${Uri.encodeComponent(filename)}';
  }
}

// ============================================================
// HOME ANNOUNCEMENT SECTION
// ============================================================

class AnnouncementSection extends StatefulWidget {
  const AnnouncementSection({
    super.key,
  });

  @override
  State<AnnouncementSection> createState() => _AnnouncementSectionState();
}

class _AnnouncementSectionState extends State<AnnouncementSection> {
  final AnnouncementService _service = AnnouncementService();
  List<Announcement> _announcements = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    try {
      final result = await _service.getAnnouncements();
      if (!mounted) return;
      setState(() {
        _announcements = result;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _announcements = [];
        _isLoading = false;
        _hasError = true;
      });

      debugPrint(
        'Announcement error: $e',
      );
    }
  }

  List<String> _getAnnouncementDetails(
    Announcement announcement,
  ) {
    final result = <String>[];
    final header = announcement.header?.trim();
    final subheader = announcement.subheader?.trim();

    if (header != null && header.isNotEmpty) {
      result.add(header);
    }

    if (subheader != null && subheader.isNotEmpty) {
      result.add(subheader);
    }

    return result;
  }

  void _openDetail(
    Announcement announcement,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return AnnouncementDetailSheet(
          announcement: announcement,
        );
      },
    );
  }

  void _openSeeAll() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AnnouncementPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildContainer(
        child: const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 24,
          ),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(
                  0xFF1E88E5,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return _buildContainer(
        child: const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 20,
          ),
          child: Center(
            child: Text(
              'Gagal memuat announcement',
              style: TextStyle(
                fontSize: 12,
                color: Color(
                  0xFF7A8496,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_announcements.isEmpty) {
      return _buildContainer(
        child: const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 20,
          ),
          child: Center(
            child: Text(
              'Belum ada announcement',
              style: TextStyle(
                fontSize: 12,
                color: Color(
                  0xFF7A8496,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final displayList = _announcements.take(5).toList();
    return _buildContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Announcement',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(
                0xFF172033,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(
            displayList.length,
            (index) {
              final item = displayList[index];
              final details = _getAnnouncementDetails(
                item,
              );

              return Column(
                children: [
                  _buildAnnouncementRow(
                    item,
                    details,
                  ),
                  if (index != displayList.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 2,
                      ),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(
                          0xFFE7EAF0,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (_announcements.length > 5) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openSeeAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(
                          0xFF1E88E5,
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: Color(
                        0xFF1E88E5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContainer({
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        0,
      ),
      padding: const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(
            0xFFE7EAF0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAnnouncementRow(
    Announcement announcement,
    List<String> details,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(announcement),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 11,
            horizontal: 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(
                  top: 5,
                  right: 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(
                    0xFF1E88E5,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(
                          0xFF172033,
                        ),
                        height: 1.3,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      ...details.map(
                        (detail) => Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(
                              0xFF7A8496,
                            ),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 15,
                color: Color(
                  0xFFB0B7C3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnnouncementDetailSheet extends StatelessWidget {
  final Announcement announcement;
  const AnnouncementDetailSheet({
    super.key,
    required this.announcement,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFFD8DCE3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Announcement Detail',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(
                          0xFF172033,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE7EAF0)),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TITLE
                    if (announcement.title.trim().isNotEmpty)
                      Text(
                        announcement.title,
                        style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                            color: Color(0xFF172033)),
                      ),

                    if (announcement.title.trim().isNotEmpty)
                      const SizedBox(height: 16),

                    // HEADER
                    if (announcement.header != null &&
                        announcement.header!.trim().isNotEmpty)
                      Text(
                        announcement.header!,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                            color: Color(0xFF172033)),
                      ),

                    // SUBHEADER
                    if (announcement.subheader != null &&
                        announcement.subheader!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          announcement.subheader!,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                              color: Color(0xFF5F6B7A)),
                        ),
                      ),

                    // BODY
                    if (announcement.body != null &&
                        announcement.body!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          announcement.body!,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 1.6,
                              color: Color(0xFF172033)),
                        ),
                      ),

                    // FOOTER
                    _buildDetail('Footer', announcement.footer),
                    // NOTES
                    _buildDetail('Notes', announcement.notes),
                    // AUTHOR
                    _buildAuthor(announcement.author),

                    // ATTACHMENT
                    if (announcement.filename != null &&
                        announcement.filename!.trim().isNotEmpty)
                      _buildAttachment(context, announcement.filename!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(
    String label,
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(
                0xFF7A8496,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(
                0xFF172033,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthor(String? author) {
    if (author == null || author.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: 18,
        bottom: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Author',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A8496),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            author,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF172033),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachment(
    BuildContext context,
    String filename,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AnnouncementFilePreview(
            filename: filename,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(
            0xFFF7F8FA,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(
              0xFFE7EAF0,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(
                  0xFF1E88E5,
                ).withOpacity(0.10),
                borderRadius: BorderRadius.circular(
                  12,
                ),
              ),
              child: const Icon(
                CupertinoIcons.doc_text_fill,
                color: Color(
                  0xFF1E88E5,
                ),
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attachment',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(
                        0xFF7A8496,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(
                        0xFF172033,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.eye_fill,
              size: 18,
              color: Color(
                0xFF1E88E5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({
    super.key,
  });

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  final AnnouncementService _service = AnnouncementService();

  List<Announcement> _all = [];
  List<Announcement> _filtered = [];

  List<String> _types = ['All'];
  String _selectedType = 'All';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final result = await _service.getAnnouncements();
      final typeSet = <String>{};
      for (final item in result) {
        final type = item.type?.trim();
        if (type != null && type.isNotEmpty) {
          typeSet.add(type.toUpperCase());
        }
      }

      if (!mounted) return;
      setState(() {
        _all = result;
        _filtered = result;
        _types = [
          'All',
          ...typeSet,
        ];

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  void _applyFilter(
    String type,
  ) {
    setState(() {
      _selectedType = type;

      if (type == 'All') {
        _filtered = List.from(_all);
        return;
      }

      _filtered = _all
          .where(
            (item) =>
                item.type?.trim().toLowerCase() == type.trim().toLowerCase(),
          )
          .toList();
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Announcement',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(
                  0xFF1E88E5,
                ),
              ),
            )
          : Column(
              children: [
                _buildFilter(),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada announcement',
                            style: TextStyle(
                              color: Color(
                                0xFF7A8496,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            8,
                            20,
                            30,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (
                            context,
                            index,
                          ) {
                            final item = _filtered[index];

                            return _buildAllItem(
                              item,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(
            0xFFE7EAF0,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.line_horizontal_3_decrease,
            size: 18,
            color: Color(
              0xFF1A365D,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Type',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(
                0xFF172033,
              ),
            ),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              borderRadius: BorderRadius.circular(
                14,
              ),
              items: _types
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        type,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _applyFilter(
                    value,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllItem(
    Announcement item,
  ) {
    final details = <String>[];

    if (item.header != null && item.header!.trim().isNotEmpty) {
      details.add(
        item.header!,
      );
    }

    if (item.subheader != null && item.subheader!.trim().isNotEmpty) {
      details.add(
        item.subheader!,
      );
    }

    return Column(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            18,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(
              18,
            ),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AnnouncementDetailSheet(
                  announcement: item,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(
                15,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF1E88E5,
                      ).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.bell_fill,
                      size: 19,
                      color: Color(
                        0xFF1E88E5,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(
                                    0xFF172033,
                                  ),
                                ),
                              ),
                            ),
                            if (item.type != null)
                              Container(
                                margin: const EdgeInsets.only(
                                  left: 8,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1E88E5,
                                  ).withOpacity(
                                    0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    8,
                                  ),
                                ),
                                child: Text(
                                  item.type!,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(
                                      0xFF1E88E5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(
                            height: 5,
                          ),
                          ...details.map(
                            (detail) => Text(
                              detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(
                                  0xFF7A8496,
                                ),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class AnnouncementFilePreview extends StatefulWidget {
  final String filename;

  const AnnouncementFilePreview({
    super.key,
    required this.filename,
  });

  @override
  State<AnnouncementFilePreview> createState() =>
      _AnnouncementFilePreviewState();
}

class _AnnouncementFilePreviewState extends State<AnnouncementFilePreview> {
  bool _downloading = false;

  String get extension {
    final index = widget.filename.lastIndexOf('.');

    if (index == -1) {
      return '';
    }

    return widget.filename.substring(index + 1).toLowerCase();
  }

  bool get isPdf => extension == 'pdf';

  bool get isImage => [
        'png',
        'jpg',
        'jpeg',
        'webp',
      ].contains(extension);

  String get previewUrl => 'http://192.168.0.151:8000/api/'
      'announcement-file/preview/'
      '${Uri.encodeComponent(widget.filename)}';

  String get downloadUrl => 'http://192.168.0.151:8000/api/'
      'announcement-file/download/'
      '${Uri.encodeComponent(widget.filename)}';

  Future<void> _download() async {
    setState(() {
      _downloading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(downloadUrl),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Download gagal',
        );
      }

      MimeType mimeType = MimeType.other;

      if (isPdf) {
        mimeType = MimeType.pdf;
      } else if (extension == 'png') {
        mimeType = MimeType.png;
      } else if (extension == 'jpg' || extension == 'jpeg') {
        mimeType = MimeType.jpeg;
      } else if (extension == 'webp') {
        mimeType = MimeType.webp;
      }

      await FileSaver.instance.saveFile(
        name: widget.filename,
        bytes: Uint8List.fromList(
          response.bodyBytes,
        ),
        mimeType: mimeType,
        includeExtension: false,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'File berhasil disimpan.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal download: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Color(
                  0xFFD8DCE3,
                ),
                borderRadius: BorderRadius.circular(
                  10,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(
                          0xFF172033,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _downloading ? null : _download,
                    icon: _downloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.arrow_down_to_line,
                            color: Color(
                              0xFF1E88E5,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _buildPreview(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (isPdf) {
      return SfPdfViewer.network(
        previewUrl,
        enableDoubleTapZooming: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      );
    }

    if (isImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            previewUrl,
            fit: BoxFit.contain,
            loadingBuilder: (
              context,
              child,
              loadingProgress,
            ) {
              if (loadingProgress == null) {
                return child;
              }

              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              );
            },
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return const Center(
                child: Text(
                  'Preview file gagal.',
                ),
              );
            },
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.doc_fill,
              size: 50,
              color: Color(
                0xFF9AA3B2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Format file ini belum mendukung preview.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _downloading ? null : _download,
              icon: const Icon(
                CupertinoIcons.arrow_down_to_line,
              ),
              label: const Text(
                'Download',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
