import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/announcements_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';
import 'create_edit_announcement_screen.dart';
import 'view_announcement_screen.dart';

class _ANColors {
  static const title = Color(0xFF1B5E20);
  static const sub   = Color(0xFF7A9A7A);
  static const green = Color(0xFF2E7D32);
  static const border= Color(0xFFC8DDC8);
}

const List<String> kPostTypes = ['Activity', 'Seminar', 'Notice', 'Announcement', 'Event'];

const Map<String, Color> kTypeColors = {
  'Activity': Color(0xFF2E7D32),
  'Seminar': Color(0xFF1565C0),
  'Notice': Color(0xFFF57F17),
  'Announcement': Color(0xFFC62828),
  'Event': Color(0xFF6A1B9A),
};
const Map<String, Color> kTypeBg = {
  'Activity': Color(0xFFE8F5E9),
  'Seminar': Color(0xFFE3F2FD),
  'Notice': Color(0xFFFFF8E1),
  'Announcement': Color(0xFFFCE4EC),
  'Event': Color(0xFFF3E5F5),
};

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  List<dynamic> _posts = [];
  bool _loading = true;
  String _filter = 'All';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await AnnouncementsService.getAnnouncements();
      if (mounted) setState(() => _posts = data);
    } catch (_) {
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  // ── BAGO: React / un-react — i-update lang lokal, walang buong re-fetch ──
  Future<void> _handleReact(dynamic post, String reactionType) async {
    try {
      await AnnouncementsService.react(post['id'], reactionType);
      // Kailangan din ng buong `reactions` list (para sa "reacted by")
      // kaya nag-re-refresh tayo — hindi masyadong mabigat naman.
      await _fetchPosts(silent: true);
    } catch (_) {}
  }

  List<dynamic> get _filtered {
    final list = _posts.where((p) {
      final matchType = _filter == 'All' || p['type'] == _filter;
      final q = _search.toLowerCase();
      return matchType && (
        '${p['title'] ?? ''}'.toLowerCase().contains(q) ||
        '${p['body'] ?? ''}'.toLowerCase().contains(q)
      );
    }).toList();
    final pinned = list.where((p) => p['pinned'] == true).toList();
    final regular = list.where((p) => p['pinned'] != true).toList();
    return [...pinned, ...regular];
  }

  Map<String, int> get _stats => {
        'total': _posts.length,
        'pinned': _posts.where((p) => p['pinned'] == true).length,
        'comments': _posts.fold<int>(0, (s, p) => s + ((p['comment_count'] ?? 0) as int)),
        'notified': _posts.where((p) => p['notified'] == true).length,
      };

  void _openCreate() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const CreateEditAnnouncementScreen()));
    if (created == true) _fetchPosts(silent: true);
  }

  void _openView(dynamic post) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => ViewAnnouncementScreen(post: post)));
    if (changed == true) _fetchPosts(silent: true);
  }

  void _quickEdit(dynamic post) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => CreateEditAnnouncementScreen(editPost: post)));
    if (changed == true) _fetchPosts(silent: true);
  }

  Future<void> _quickDelete(dynamic post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Announcement', style: TextStyle(color: Color(0xFFC62828), fontSize: 15)),
        content: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828), size: 36),
          SizedBox(height: 10),
          Text('Are you sure you want to delete this announcement?', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('This action cannot be undone.', style: TextStyle(fontSize: 11, color: _ANColors.sub)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AnnouncementsService.deleteAnnouncement(post['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement deleted.'), backgroundColor: Color(0xFFC62828)));
        _fetchPosts(silent: true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete.'), backgroundColor: Color(0xFFC62828)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final filtered = _filtered;
    final auth = context.watch<AuthProvider>();
    final canManage = auth.role == 'admin' || auth.role == 'staff';

    return AdminScreenScaffold(
      activeRouteKey: 'announcement',
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        backgroundColor: _ANColors.green,
        tooltip: 'Create Post',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchPosts(),
        color: _ANColors.green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ANNOUNCEMENT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ANColors.title, letterSpacing: 0.3)),
              const SizedBox(height: 3),
              const Text('Post activities, seminars, and notices to members. Posts are sent as notifications and appear in the member newsfeed.', style: TextStyle(fontSize: 11, color: _ANColors.sub, height: 1.4)),
              const SizedBox(height: 14),

              Row(children: [
                Expanded(child: _StatChip(value: '${stats['total']}', label: 'Total Post')),
                const SizedBox(width: 8),
                Expanded(child: _StatChip(value: '${stats['pinned']}', label: 'Pinned')),
                const SizedBox(width: 8),
                Expanded(child: _StatChip(value: '${stats['comments']}', label: 'Comments')),
                const SizedBox(width: 8),
                Expanded(child: _StatChip(value: '${stats['notified']}', label: 'Notified', color: const Color(0xFF1565C0))),
              ]),
              const SizedBox(height: 14),

              Container(
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _ANColors.border), borderRadius: BorderRadius.circular(8)),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Search Post.....',
                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                    prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFFAAAAAA)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kPostTypes.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final t = i == 0 ? 'All' : kPostTypes[i - 1];
                    final active = _filter == t;
                    return ChoiceChip(
                      label: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF555555))),
                      selected: active,
                      selectedColor: _ANColors.green,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: active ? _ANColors.green : _ANColors.border),
                      onSelected: (_) => setState(() => _filter = t),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: _ANColors.green)))
              else if (filtered.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No announcements found.', style: TextStyle(color: _ANColors.sub))))
              else
                ...filtered.map((p) => _PostCard(post: p, onTap: () => _openView(p), canManage: canManage, onEdit: () => _quickEdit(p), onDelete: () => _quickDelete(p), onReact: (type) => _handleReact(p, type))),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  const _StatChip({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _ANColors.border), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color ?? _ANColors.title)),
          Text(label, style: const TextStyle(fontSize: 8.5, color: _ANColors.sub, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final dynamic post;
  final VoidCallback onTap;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String type) onReact;
  const _PostCard({required this.post, required this.onTap, required this.canManage, required this.onEdit, required this.onDelete, required this.onReact});

  @override
  Widget build(BuildContext context) {
    final type = (post['type'] ?? 'Activity').toString();
    final isPinned = post['pinned'] == true;
    final authorName = post['posted_by_name'] ?? 'Admin';
    final bodyText = (post['body'] ?? post['caption'] ?? '').toString();
    final imageUrl = post['image_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPinned ? const Color(0xFFC8E6C9) : const Color(0xFFE4EEDE)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPinned)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: const BoxDecoration(color: Color(0xFFF1F8E9), border: Border(bottom: BorderSide(color: Color(0xFFE8F5E9)))),
                  child: const Row(children: [
                    Icon(Icons.push_pin, size: 11, color: _ANColors.green),
                    SizedBox(width: 4),
                    Text('Pinned', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _ANColors.green)),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 18, backgroundColor: _ANColors.green, child: Text(authorName.toString().isNotEmpty ? authorName.toString()[0].toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                Text('$authorName', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: (post['posted_by_role'] == 'staff') ? const Color(0xFFE3F2FD) : const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                                  child: Text('${post['posted_by_role'] ?? 'admin'}', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: (post['posted_by_role'] == 'staff') ? const Color(0xFF1565C0) : _ANColors.green)),
                                ),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: kTypeBg[type] ?? const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20)),
                              child: Text(type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kTypeColors[type] ?? const Color(0xFF888888))),
                            ),
                            if (canManage) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: onEdit,
                                child: Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(6)),
                                  child: const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF888888)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: onDelete,
                                child: Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(6)),
                                  child: const Icon(Icons.delete_outline, size: 12, color: Color(0xFF888888)),
                                ),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 2),
                          Text('${post['created_at'] ?? ''}'.split('T').first, style: const TextStyle(fontSize: 9.5, color: Color(0xFFBBBBBB))),
                          const SizedBox(height: 6),
                          Text('${post['title'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ANColors.title)),
                          const SizedBox(height: 4),
                          Text(
                            bodyText.length > 140 ? '${bodyText.substring(0, 140)}...' : bodyText,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF555555), height: 1.4),
                          ),
                          if (imageUrl != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(maxHeight: 300),
                                color: const Color(0xFFF5F5F5),
                                child: Image.network(
                                  imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.fitWidth,
                                  errorBuilder: (context, error, stack) => Container(height: 160, color: const Color(0xFFF5F5F5)),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.only(top: 8),
                            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F5F0)))),
                            child: Row(children: [
                              _AdminReactionButton(
                                myReaction: post['my_reaction'],
                                totalReactions: (post['total_reactions'] as int?) ?? 0,
                                reactions: post['reactions'] as List<dynamic>?,
                                onReact: (type) => onReact(type),
                              ),
                              const Spacer(),
                              const Icon(Icons.mode_comment_outlined, size: 13, color: Color(0xFF888888)),
                              const SizedBox(width: 5),
                              Text('${post['comment_count'] ?? 0} Comments', style: const TextStyle(fontSize: 10.5, color: Color(0xFF888888))),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── BAGO: Reaction button — tap = toggle "Like", long-press = pumili ────
// ── BAGO: dating naka-emoji ito (👍❤️😂😮😢😠) — ngayon totoong
// Material icons, tugma sa "walang emoji" na patakaran sa buong system.
// Walang eksaktong Material icon para sa "surprised/wow" face, kaya
// "auto_awesome" (parang sparkle) ang ginamit kong pinakamalapit na
// alternatibo. ─────────────────────────────────────────────────────────
const Map<String, IconData> _kReactionIcon = {
  'Like': Icons.thumb_up,
  'Love': Icons.favorite,
  'Haha': Icons.sentiment_very_satisfied,
  'Wow': Icons.auto_awesome,
  'Sad': Icons.sentiment_dissatisfied,
  'Angry': Icons.mood_bad,
};
const Map<String, Color> _kReactionColor = {
  'Like': Color(0xFF1565C0), 'Love': Color(0xFFC62828), 'Haha': Color(0xFFF57F17),
  'Wow': Color(0xFFF57F17), 'Sad': Color(0xFFF57F17), 'Angry': Color(0xFFE65100),
};

class _AdminReactionButton extends StatelessWidget {
  final String? myReaction;
  final int totalReactions;
  final List<dynamic>? reactions;
  final void Function(String type) onReact;
  const _AdminReactionButton({required this.myReaction, required this.totalReactions, required this.onReact, this.reactions});

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
              children: _kReactionIcon.entries.map((e) => GestureDetector(
                    onTap: () { onReact(e.key); entry.remove(); },
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(e.value, size: 22, color: _kReactionColor[e.key])),
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
                              Icon(_kReactionIcon[r['reaction_type']] ?? Icons.thumb_up, size: 16, color: _kReactionColor[r['reaction_type']] ?? const Color(0xFF888888)),
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
    final iconData = myReaction != null ? _kReactionIcon[myReaction!] ?? Icons.thumb_up : Icons.thumb_up;
    final color = myReaction != null ? (_kReactionColor[myReaction!] ?? _ANColors.green) : const Color(0xFF888888);
    final label = myReaction ?? 'Like';

    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onLongPressStart: (details) => _showPicker(context, details.globalPosition),
        child: TextButton.icon(
          onPressed: () => onReact(myReaction ?? 'Like'),
          style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          icon: Icon(iconData, size: 14, color: color),
          label: Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w600)),
        ),
      ),
      if (totalReactions > 0)
        GestureDetector(
          onTap: () => _showReactedBy(context),
          child: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text('$totalReactions reacted', style: const TextStyle(fontSize: 10, color: Color(0xFF888888), decoration: TextDecoration.underline)),
          ),
        ),
    ]);
  }
}