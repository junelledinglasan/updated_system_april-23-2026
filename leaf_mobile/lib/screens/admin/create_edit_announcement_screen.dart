import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/announcements_service.dart';
import 'announcement_screen.dart';

class _CEColors {
  static const title = Color(0xFF1B5E20);
  static const sub   = Color(0xFF888888);
  static const green = Color(0xFF2E7D32);
  static const red   = Color(0xFFE53935);
}

class CreateEditAnnouncementScreen extends StatefulWidget {
  final dynamic editPost;
  const CreateEditAnnouncementScreen({super.key, this.editPost});

  @override
  State<CreateEditAnnouncementScreen> createState() => _CreateEditAnnouncementScreenState();
}

class _CreateEditAnnouncementScreenState extends State<CreateEditAnnouncementScreen> {
  late String _type;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _captionCtrl;
  late bool _pinned;
  Uint8List? _imageBytes;
  String? _imageFilename;
  String? _existingImageUrl;
  final Map<String, String> _errors = {};
  bool _loading = false;

  bool get _isEdit => widget.editPost != null;

  @override
  void initState() {
    super.initState();
    final p = widget.editPost;
    _type = p?['type'] ?? 'Activity';
    _titleCtrl = TextEditingController(text: p?['title'] ?? '');
    _captionCtrl = TextEditingController(text: p?['body'] ?? p?['caption'] ?? '');
    _pinned = p?['pinned'] ?? false;
    _existingImageUrl = p?['image_url'];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageFilename = picked.name;
      _existingImageUrl = null; // papalitan na yung dating image
    });
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    if (_titleCtrl.text.trim().isEmpty) e['title'] = 'Title is required.';
    if (_captionCtrl.text.trim().isEmpty) e['caption'] = 'Caption is required.';
    return e;
  }

  Future<void> _handleSubmit() async {
    final errs = _validate();
    if (errs.isNotEmpty) { setState(() => _errors..clear()..addAll(errs)); return; }
    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await AnnouncementsService.updateAnnouncement(
          id: widget.editPost['id'],
          type: _type,
          title: _titleCtrl.text,
          body: _captionCtrl.text,
          pinned: _pinned,
          imageBytes: _imageBytes,
          imageFilename: _imageFilename,
        );
      } else {
        await AnnouncementsService.createAnnouncement(
          type: _type,
          title: _titleCtrl.text,
          body: _captionCtrl.text,
          pinned: _pinned,
          imageBytes: _imageBytes,
          imageFilename: _imageFilename,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Announcement updated!' : 'Announcement posted successfully!'), backgroundColor: _CEColors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Failed to update.' : 'Failed to post announcement.'), backgroundColor: _CEColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8E8CC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _CEColors.title,
        elevation: 0.5,
        title: Text(_isEdit ? 'Edit Post' : 'Create New Post', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _CEColors.title)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(TextSpan(text: 'Post Type', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _CEColors.sub, letterSpacing: 0.4), children: const [TextSpan(text: ' *', style: TextStyle(color: _CEColors.red))])),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kPostTypes.map((t) {
                final active = _type == t;
                final color = kTypeColors[t] ?? _CEColors.green;
                return ChoiceChip(
                  label: Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: active ? color : color.withOpacity(0.8))),
                  selected: active,
                  selectedColor: (kTypeBg[t] ?? Colors.white).withOpacity(1),
                  backgroundColor: (kTypeBg[t] ?? Colors.white),
                  side: BorderSide(color: active ? color : color.withOpacity(0.3), width: active ? 2 : 1),
                  onSelected: (_) => setState(() => _type = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                value: _pinned,
                onChanged: (v) => setState(() => _pinned = v ?? false),
                title: const Row(children: [Icon(Icons.push_pin_outlined, size: 15), SizedBox(width: 6), Text('Pin this post', style: TextStyle(fontSize: 12.5))]),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const SizedBox(height: 10),

            Text.rich(TextSpan(text: 'Title', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _CEColors.sub, letterSpacing: 0.4), children: const [TextSpan(text: ' *', style: TextStyle(color: _CEColors.red))])),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              maxLength: 100,
              onChanged: (_) => setState(() => _errors.remove('title')),
              decoration: InputDecoration(hintText: 'e.g. Annual General Assembly 2026', filled: true, fillColor: const Color(0xFFF7FAF7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDDEEDD))), errorText: _errors['title']),
            ),
            const SizedBox(height: 10),

            Text.rich(TextSpan(text: 'Caption / Description', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _CEColors.sub, letterSpacing: 0.4), children: const [TextSpan(text: ' *', style: TextStyle(color: _CEColors.red))])),
            const SizedBox(height: 6),
            TextField(
              controller: _captionCtrl,
              maxLines: 6,
              onChanged: (_) => setState(() => _errors.remove('caption')),
              decoration: InputDecoration(hintText: 'Write the announcement details here...', filled: true, fillColor: const Color(0xFFF7FAF7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDDEEDD))), errorText: _errors['caption']),
            ),
            const SizedBox(height: 14),

            const Text('Attach Image (optional)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _CEColors.sub, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.attach_file, size: 16),
              label: const Text('Choose Image'),
              style: OutlinedButton.styleFrom(foregroundColor: _CEColors.green, side: const BorderSide(color: Color(0xFFC8DDC8))),
            ),
            if (_imageBytes != null || _existingImageUrl != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _imageBytes != null
                    ? Image.memory(_imageBytes!, height: 180, width: double.infinity, fit: BoxFit.cover)
                    : Image.network(_existingImageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(height: 180, color: const Color(0xFFF0F0F0))),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => setState(() { _imageBytes = null; _imageFilename = null; _existingImageUrl = null; }),
                icon: const Icon(Icons.close, size: 14, color: _CEColors.red),
                label: const Text('Remove', style: TextStyle(color: _CEColors.red, fontSize: 11.5)),
              ),
            ],
          ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _CEColors.green, foregroundColor: Colors.white),
                onPressed: _loading ? null : _handleSubmit,
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEdit ? 'Save Changes' : 'Post Announcement'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}