import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/announcements_service.dart';
import 'announcement_screen.dart';
import 'create_edit_announcement_screen.dart';

class _VAColors {
  static const title = Color(0xFF1B5E20);
  static const sub   = Color(0xFF888888);
  static const green = Color(0xFF2E7D32);
  static const red   = Color(0xFFC62828);
}

class ViewAnnouncementScreen extends StatefulWidget {
  final dynamic post;
  const ViewAnnouncementScreen({super.key, required this.post});

  @override
  State<ViewAnnouncementScreen> createState() => _ViewAnnouncementScreenState();
}

class _ViewAnnouncementScreenState extends State<ViewAnnouncementScreen> {
  List<dynamic> _comments = [];
  bool _fetching = false;
  final _commentCtrl = TextEditingController();
  bool _sending = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _comments = widget.post['comments'] ?? [];
    _refreshComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshComments() async {
    setState(() => _fetching = true);
    try {
      final posts = await AnnouncementsService.getAnnouncements();
      final found = posts.firstWhere((p) => p['id'] == widget.post['id'], orElse: () => null);
      if (found != null && mounted) setState(() => _comments = found['comments'] ?? []);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  // ── BAGO: React / un-react ──────────────────────────────────────────
  Future<void> _handleReact(String reactionType) async {
    try {
      await AnnouncementsService.react(widget.post['id'], reactionType);
      // Kailangan din ng buong `reactions` list (para sa "reacted by") —
      // walang list-level refetch dito (single-post view lang ito), kaya
      // kunin natin lahat ulit at hanapin ang parehong post.
      final posts = await AnnouncementsService.getAnnouncements();
      final found = posts.firstWhere((p) => p['id'] == widget.post['id'], orElse: () => null);
      if (found != null && mounted) {
        setState(() {
          widget.post['reaction_counts'] = found['reaction_counts'];
          widget.post['total_reactions'] = found['total_reactions'];
          widget.post['my_reaction'] = found['my_reaction'];
          widget.post['reactions'] = found['reactions'];
          _changed = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleAddComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final newComment = await AnnouncementsService.addComment(widget.post['id'], _commentCtrl.text);
      if (mounted) {
        setState(() {
          _comments = [..._comments, newComment];
          _commentCtrl.clear();
          _changed = true;
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add comment.'), backgroundColor: _VAColors.red));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _handleDeleteComment(int commentId) async {
    try {
      await AnnouncementsService.deleteComment(widget.post['id'], commentId);
      if (mounted) {
        setState(() {
          _comments = _comments.where((c) => c['id'] != commentId).toList();
          _changed = true;
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete comment.'), backgroundColor: _VAColors.red));
    }
  }

  void _openEdit() async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => CreateEditAnnouncementScreen(editPost: widget.post)));
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Announcement', style: TextStyle(color: _VAColors.red, fontSize: 15)),
        content: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.warning_amber_rounded, color: _VAColors.red, size: 36),
          SizedBox(height: 10),
          Text('Are you sure you want to delete this announcement?', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('This action cannot be undone.', style: TextStyle(fontSize: 11, color: _VAColors.sub)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _VAColors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AnnouncementsService.deleteAnnouncement(widget.post['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement deleted.'), backgroundColor: _VAColors.red));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete.'), backgroundColor: _VAColors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final type = (post['type'] ?? 'Activity').toString();
    final bodyText = (post['body'] ?? post['caption'] ?? '').toString();
    final imageUrl = post['image_url'];
    final auth = context.watch<AuthProvider>();
    final canManage = auth.role == 'admin' || auth.role == 'staff';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFD8E8CC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _VAColors.title,
          elevation: 0.5,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context, _changed)),
          title: Text('${post['title'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _VAColors.title), overflow: TextOverflow.ellipsis),
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
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: kTypeBg[type] ?? const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20)),
                  child: Text(type, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: kTypeColors[type] ?? const Color(0xFF888888))),
                ),
                Text('by ${post['posted_by_name'] ?? 'Admin'}', style: const TextStyle(fontSize: 10.5, color: _VAColors.sub)),
                Text('${post['created_at'] ?? ''}'.split('T').first, style: const TextStyle(fontSize: 10.5, color: Color(0xFFBBBBBB))),
              ]),
              const SizedBox(height: 12),

              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 420),
                    color: const Color(0xFFF5F5F5),
                    child: Image.network(imageUrl, width: double.infinity, fit: BoxFit.fitWidth, errorBuilder: (c, e, s) => Container(height: 200, color: const Color(0xFFF0F0F0))),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4F0E5))),
                child: Text(bodyText, style: const TextStyle(fontSize: 13.5, color: Color(0xFF333333), height: 1.6)),
              ),
              const SizedBox(height: 12),

              _AdminReactionButtonVA(
                myReaction: post['my_reaction'],
                totalReactions: (post['total_reactions'] as int?) ?? 0,
                reactions: post['reactions'] as List<dynamic>?,
                onReact: _handleReact,
              ),
              const SizedBox(height: 8),

              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0EAD8))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Comments (${_comments.length})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                    const SizedBox(height: 10),
                    if (_fetching)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                    else if (_comments.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: Text('No comments yet. Be the first to comment!', style: TextStyle(fontSize: 11.5, color: _VAColors.sub))))
                    else
                      ..._comments.map((c) {
                        final canDeleteThis = auth.role == 'admin' || auth.username == '${c['posted_by']}';
                        final authorName = c['posted_by_name'] ?? 'U';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(radius: 14, backgroundColor: _VAColors.green, child: Text(authorName.toString().isNotEmpty ? authorName.toString()[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700))),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(color: const Color(0xFFF8FAF8), borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text('$authorName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                        const SizedBox(width: 6),
                                        Text('${c['posted_by_role'] ?? ''}', style: const TextStyle(fontSize: 9.5, color: _VAColors.sub)),
                                      ]),
                                      Text('${c['body'] ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
                                      Text('${c['created_at'] ?? ''}', style: const TextStyle(fontSize: 9.5, color: Color(0xFFBBBBBB))),
                                    ],
                                  ),
                                ),
                              ),
                              if (canDeleteThis)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 15, color: Color(0xFFCCCCCC)),
                                  onPressed: () => _handleDeleteComment(c['id']),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          decoration: InputDecoration(hintText: 'Write a comment...', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          onSubmitted: (_) => _handleAddComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _VAColors.green, foregroundColor: Colors.white),
                        onPressed: (_commentCtrl.text.trim().isEmpty || _sending) ? null : _handleAddComment,
                        child: _sending ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send'),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, -2))]),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, _changed), child: const Text('Close'))),
                if (canManage) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _VAColors.green, foregroundColor: Colors.white),
                      onPressed: _openEdit,
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _VAColors.red, foregroundColor: Colors.white),
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline, size: 15),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── BAGO: Reaction button — tap = toggle "Like", long-press = pumili ────
const Map<String, String> _kReactionEmojiVA = {
  'Like': '👍', 'Love': '❤️', 'Haha': '😂', 'Wow': '😮', 'Sad': '😢', 'Angry': '😠',
};
const Map<String, Color> _kReactionColorVA = {
  'Like': Color(0xFF1565C0), 'Love': Color(0xFFC62828), 'Haha': Color(0xFFF57F17),
  'Wow': Color(0xFFF57F17), 'Sad': Color(0xFFF57F17), 'Angry': Color(0xFFE65100),
};

class _AdminReactionButtonVA extends StatelessWidget {
  final String? myReaction;
  final int totalReactions;
  final List<dynamic>? reactions;
  final void Function(String type) onReact;
  const _AdminReactionButtonVA({required this.myReaction, required this.totalReactions, required this.onReact, this.reactions});

  void _showPicker(BuildContext context, Offset globalPos) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: (globalPos.dx - 130).clamp(8, MediaQuery.of(context).size.width - 268),
        top: globalPos.dy - 56,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10)]),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _kReactionEmojiVA.entries.map((e) => GestureDetector(
                    onTap: () { onReact(e.key); entry.remove(); },
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(e.value, style: const TextStyle(fontSize: 24))),
                  )).toList(),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () { if (entry.mounted) entry.remove(); });
  }

  // ── "Reacted by" — i-tap ang count para makita ang mga pangalan ────
  void _showReactedBy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reacted by', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20))),
              const SizedBox(height: 10),
              if (reactions == null || reactions!.isEmpty)
                const Text('No reactions yet.', style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: reactions!.map((r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Text(_kReactionEmojiVA[r['reaction_type']] ?? '👍', style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Text('${r['posted_by_name'] ?? 'User'}', style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
                            ]),
                          )).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = myReaction != null;
    final emoji = myReaction != null ? _kReactionEmojiVA[myReaction!] ?? '👍' : '👍';
    final color = myReaction != null ? (_kReactionColorVA[myReaction!] ?? _VAColors.green) : const Color(0xFF888888);
    final label = myReaction ?? 'Like';

    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onLongPressStart: (details) => _showPicker(context, details.globalPosition),
        child: TextButton.icon(
          onPressed: () => onReact(myReaction ?? 'Like'),
          style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          icon: Text(emoji, style: const TextStyle(fontSize: 13)),
          label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w800 : FontWeight.w600)),
        ),
      ),
      if (totalReactions > 0)
        GestureDetector(
          onTap: () => _showReactedBy(context),
          child: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text('$totalReactions reacted', style: const TextStyle(fontSize: 10.5, color: Color(0xFF888888), decoration: TextDecoration.underline)),
          ),
        ),
    ]);
  }
}