// ============================================================
// Photo Upload Widget
// Reusable for Student, Employee, and Guardian photos
// ============================================================
library photo_upload_widget;

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

/// Entity types supported
enum PhotoEntityType { student, employee, guardian }

/// Callback fired after successful upload, receives the new photo URL
typedef PhotoUploadCallback = void Function(String url);

/// Naming convention: {entityType}_{entityRef}_{timestamp}.webp
/// e.g. student_STU2026001_1711123456.webp
/// The server handles the actual file naming — we just pass the context.

class PhotoUploadWidget extends StatefulWidget {
  final PhotoEntityType entityType;

  /// The entity's primary key (UUID) — used to PATCH the photo_url after upload
  final String? entityId;

  /// Human-readable reference (student_id, employee_id, guardian name)
  /// used to suggest the filename sent to the server
  final String? entityRef;

  /// Current photo URL (shown as preview)
  final String? currentPhotoUrl;

  /// Called after successful upload + optional entity patch
  final PhotoUploadCallback? onUploaded;

  /// Whether to auto-save the URL back to the entity record
  /// e.g. PATCH /students/{entityId} {photo_url: url}
  final bool autoSave;

  /// Size of the avatar display
  final double size;

  const PhotoUploadWidget({
    super.key,
    required this.entityType,
    this.entityId,
    this.entityRef,
    this.currentPhotoUrl,
    this.onUploaded,
    this.autoSave = true,
    this.size = 100,
  });

  @override
  State<PhotoUploadWidget> createState() => _PhotoUploadWidgetState();
}

class _PhotoUploadWidgetState extends State<PhotoUploadWidget> {
  Uint8List? _previewBytes;
  String? _displayUrl;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _displayUrl = widget.currentPhotoUrl;
  }

  String get _entityLabel => switch (widget.entityType) {
        PhotoEntityType.student  => 'student',
        PhotoEntityType.employee => 'employee',
        PhotoEntityType.guardian => 'guardian',
      };

  String get _patchEndpoint => switch (widget.entityType) {
        PhotoEntityType.student  => '/students/${widget.entityId}',
        PhotoEntityType.employee => '/employees/${widget.entityId}',
        PhotoEntityType.guardian => '/guardians/${widget.entityId}',
      };

  Future<void> _pickAndUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if ((file.size ?? 0) > 5 * 1024 * 1024) {
        _setError('Photo must be smaller than 5 MB.');
        return;
      }

      setState(() {
        _previewBytes = file.bytes;
        _uploading = true;
        _error = null;
      });

      final api = ApiService();

      // Build a descriptive filename: entityType_ref_timestamp.ext
      final ext = file.extension ?? 'jpg';
      final ref = (widget.entityRef ?? widget.entityId ?? 'unknown')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final suggestedFilename = '${_entityLabel}_${ref}_$ts.$ext';

      // Upload to /uploads/photo
      final resp = await api.uploadFile(
        '/uploads/photo',
        file.bytes!,
        suggestedFilename,
        extraFields: {
          'entity': _entityLabel,
          if (widget.entityRef != null) 'entity_ref': widget.entityRef!,
        },
      );

      final url = resp['data']?['url']?.toString();
      if (url == null) throw Exception('Upload response missing URL');

      // Optionally auto-save back to the entity
      if (widget.autoSave && widget.entityId != null) {
        await api.put(_patchEndpoint, {'photo_url': url});
      }

      setState(() {
        _displayUrl = url;
        _previewBytes = null;
        _uploading = false;
      });

      widget.onUploaded?.call(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo updated successfully'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _setError('Upload failed: $e');
      setState(() { _previewBytes = null; _uploading = false; });
    }
  }

  Future<void> _removePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove Photo', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Remove the current photo?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (widget.autoSave && widget.entityId != null) {
      try {
        await ApiService().put(_patchEndpoint, {'photo_url': null});
      } catch (_) {}
    }
    setState(() => _displayUrl = null);
    widget.onUploaded?.call('');
  }

  void _setError(String msg) {
    setState(() => _error = msg);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            // Avatar
            GestureDetector(
              onTap: _uploading ? null : _pickAndUpload,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _uploading
                      ? Center(
                          child: SizedBox(
                            width: widget.size * 0.3,
                            height: widget.size * 0.3,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                        )
                      : _previewBytes != null
                          ? Image.memory(_previewBytes!, fit: BoxFit.cover,
                              width: widget.size, height: widget.size)
                          : _displayUrl != null && _displayUrl!.isNotEmpty
                              ? Image.network(
                                  _displayUrl!,
                                  fit: BoxFit.cover,
                                  width: widget.size,
                                  height: widget.size,
                                  errorBuilder: (_, __, ___) => _PlaceholderIcon(
                                    entityType: widget.entityType,
                                    size: widget.size,
                                  ),
                                )
                              : _PlaceholderIcon(
                                  entityType: widget.entityType,
                                  size: widget.size,
                                ),
                ),
              ),
            ),

            // Camera button
            if (!_uploading)
              GestureDetector(
                onTap: _pickAndUpload,
                child: Container(
                  width: widget.size * 0.32,
                  height: widget.size * 0.32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: widget.size * 0.16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Action links
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              icon: Icon(Icons.upload_rounded, size: 14, color: const Color(0xFF1A237E)),
              label: Text(
                _displayUrl != null ? 'Change Photo' : 'Upload Photo',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF1A237E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _uploading ? null : _pickAndUpload,
            ),
            if (_displayUrl != null && _displayUrl!.isNotEmpty) ...[
              Text('·', style: TextStyle(color: Colors.grey.shade400)),
              TextButton(
                onPressed: _uploading ? null : _removePhoto,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Remove',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
          ),

        // File format hint
        Text(
          'JPG, PNG or WEBP · max 5 MB',
          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade400),
        ),
      ],
    );
  }
}

// ── Placeholder icon by entity type ───────────────────────────
class _PlaceholderIcon extends StatelessWidget {
  final PhotoEntityType entityType;
  final double size;
  const _PlaceholderIcon({required this.entityType, required this.size});

  @override
  Widget build(BuildContext context) {
    final icon = switch (entityType) {
      PhotoEntityType.student  => Icons.school_rounded,
      PhotoEntityType.employee => Icons.badge_rounded,
      PhotoEntityType.guardian => Icons.family_restroom_rounded,
    };
    return Container(
      color: Colors.grey.shade100,
      child: Icon(icon, size: size * 0.45, color: Colors.grey.shade400),
    );
  }
}

// ── Compact inline variant (for table rows) ────────────────────
class PhotoThumbnail extends StatelessWidget {
  final String? photoUrl;
  final PhotoEntityType entityType;
  final double size;

  const PhotoThumbnail({
    super.key,
    this.photoUrl,
    required this.entityType,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipOval(
          child: photoUrl != null && photoUrl!.isNotEmpty
              ? Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _PlaceholderIcon(entityType: entityType, size: size),
                )
              : _PlaceholderIcon(entityType: entityType, size: size),
        ),
      );
}
