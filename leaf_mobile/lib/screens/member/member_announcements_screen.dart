import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/announcements_service.dart';
import '../../widgets/member_scaffold_helpers.dart';
import '../../utils/page_cache.dart';

class _MAColors {
  static const dark  = Color(0xFF1B5E20);
  static const green = Color(0xFF2E7D32);
  static const sub   = Color(0xFFAAAAAA);
}

const Map<String, Color> _tagColor = {
  'Activity': Color(0xFF1B5E20),
  'Seminar': Color(0xFF0D47A1),
  'Notice': Color(0xFFE65100),
  'Announcement': Color(0xFF4A148C),
  'Event': Color(0xFF880E4F),
};
const Map<String, Color> _tagBg = {
  'Activity': Color(0xFFE8F5E9),
  'Seminar': Color(0xFFE3F2FD),
  'Notice': Color(0xFFFFF8E1),
  'Announcement': Color(0xFFF3E5F5),
  'Event': Color(0xFFFCE4EC),
};

// ── Reaction emojis (parang Facebook) ───────────────────────────────────
const Map<String, String> _reactionEmoji = {
  'Like': '👍', 'Love': '❤️', 'Haha': '😂', 'Wow': '😮', 'Sad': '😢', 'Angry': '😠',
};
const Map<String, Color> _reactionColor = {
  'Like': Color(0xFF1565C0), 'Love': Color(0xFFC62828), 'Haha': Color(0xFFF57F17),
  'Wow': Color(0xFFF57F17), 'Sad': Color(0xFFF57F17), 'Angry': Color(0xFFE65100),
};

String _timeAgo(dynamic dateStr) {
  if (dateStr == null || '$dateStr'.isEmpty) return '';
  DateTime? d;
  try {
    d = DateTime.parse('$dateStr');
  } catch (_) {
    return '';
  }
  final diff = DateTime.now().difference(d).inSeconds;
  if (diff < 60) return 'just now';
  if (diff < 3600) return '${diff ~/ 60}m ago';
  if (diff < 86400) return '${diff ~/ 3600}h ago';
  if (diff < 604800) return '${diff ~/ 86400}d ago';
  return '${d.month}/${d.day}/${d.year}';
}

class MemberAnnouncementsScreen extends StatefulWidget {
  const MemberAnnouncementsScreen({super.key});

  @override
  State<MemberAnnouncementsScreen> createState() => _MemberAnnouncementsScreenState();
}

class _MemberAnnouncementsScreenState extends State<MemberAnnouncementsScreen> {
  List<dynamic> _posts = [];
  bool _loading = true;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    // ── BAGO: cache-first — pareho ang announcements para sa LAHAT ng
    // members (hindi per-member data), kaya "shared" na lang ang key.
    // Instant na ipinapakita ang huling nakitang listahan habang
    // tahimik na nagre-refresh sa likod. ─────────────────────────────
    final cached = PageCache.get<List<dynamic>>('announcements', 'shared');
    if (cached != null) {
      _posts = cached;
      _loading = false;
    }
    _fetch(silent: cached != null);
  }

  Future<void> _fetch({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final data = await AnnouncementsService.getAnnouncements();
      if (mounted) setState(() => _posts = data);
      PageCache.set('announcements', 'shared', data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _types {
    final s = <String>{'All'};
    for (final p in _posts) {
      if (p['type'] != null && '${p['type']}'.isNotEmpty) s.add('${p['type']}');
    }
    return s.toList();
  }

  List<dynamic> get _displayed => _filter == 'All' ? _posts : _posts.where((p) => p['type'] == _filter).toList();

  // ── I-update yung reaction data ng post nang lokal (walang refetch) ────
  Future<void> _handleReact(dynamic post, String reactionType) async {
    try {
      await AnnouncementsService.react(post['id'], reactionType);
      // Kailangan din ng buong `reactions` list (para sa "reacted by")
      // kaya nag-re-refresh tayo — hindi masyadong mabigat naman.
      await _fetch(silent: true);
    } catch (_) {}
  }

  void _openPostDetail(dynamic post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => _PostDetailSheet(
        post: post,
        onCommentAdded: () => _fetch(silent: true),
        onReact: (type) => _handleReact(post, type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayed;
    final types = _types;

    return MemberScreenScaffold(
      activeRouteKey: 'announcements',
      body: RefreshIndicator(
        onRefresh: () => _fetch(),
        color: _MAColors.green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Announcements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _MAColors.dark)),
              const SizedBox(height: 2),
              const Text('Latest updates, events, and notices from LEAF MPC.', style: TextStyle(fontSize: 11, color: _MAColors.sub)),
              const SizedBox(height: 12),

              Wrap(spacing: 6, runSpacing: 6, children: types.map((t) {
                final active = _filter == t;
                return ChoiceChip(
                  label: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888))),
                  selected: active,
                  selectedColor: _MAColors.green,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: active ? _MAColors.green : const Color(0xFFE0E8E0)),
                  onSelected: (_) => setState(() => _filter = t),
                );
              }).toList()),
              const SizedBox(height: 14),

              if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator(color: _MAColors.green)))
              else if (displayed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.campaign_outlined, size: 40, color: Color(0xFFCCCCCC)),
                      SizedBox(height: 10),
                      Text('No announcements yet.', style: TextStyle(color: _MAColors.sub)),
                    ]),
                  ),
                )
              else
                ...displayed.map((post) => _PostCard(
                      post: post,
                      onTap: () => _openPostDetail(post),
                      onReact: (type) => _handleReact(post, type),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reaction button — tap = toggle "Like", long-press = pumili ng iba ────
class _ReactionButton extends StatelessWidget {
  final String? myReaction;
  final int totalReactions;
  final List<dynamic>? reactions;
  final void Function(String type) onReact;
  final bool compact;
  const _ReactionButton({required this.myReaction, required this.totalReactions, required this.onReact, this.reactions, this.compact = false});

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
              children: _reactionEmoji.entries.map((e) => GestureDetector(
                    onTap: () { onReact(e.key); entry.remove(); },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(e.value, style: const TextStyle(fontSize: 24)),
                    ),
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
                              Text(_reactionEmoji[r['reaction_type']] ?? '👍', style: const TextStyle(fontSize: 16)),
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
    final emoji = myReaction != null ? _reactionEmoji[myReaction!] ?? '👍' : '👍';
    final color = myReaction != null ? (_reactionColor[myReaction!] ?? _MAColors.green) : const Color(0xFF888888);
    final label = myReaction ?? 'Like';

    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onLongPressStart: (details) => _showPicker(context, details.globalPosition),
        child: TextButton.icon(
          onPressed: () => onReact(myReaction ?? 'Like'),
          style: TextButton.styleFrom(foregroundColor: color, padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: 2), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          icon: Text(emoji, style: TextStyle(fontSize: compact ? 12 : 14)),
          label: Text(
            label,
            style: TextStyle(fontSize: compact ? 11 : 11.5, fontWeight: active ? FontWeight.w800 : FontWeight.w600),
          ),
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

// ─── Feed preview card — buong post na clickable ────────────────────────────
class _PostCard extends StatelessWidget {
  final dynamic post;
  final VoidCallback onTap;
  final void Function(String type) onReact;
  const _PostCard({required this.post, required this.onTap, required this.onReact});

  @override
  Widget build(BuildContext context) {
    final bodyText = '${post['body'] ?? post['caption'] ?? post['content'] ?? ''}';
    final preview = bodyText.length > 150 ? '${bodyText.substring(0, 150)}...' : bodyText;
    final authorName = '${post['posted_by_name'] ?? 'Admin'}';
    final authorRole = '${post['posted_by_role'] ?? 'admin'}';
    final type = '${post['type'] ?? ''}';
    final comments = (post['comments'] as List?) ?? [];
    final commentCount = comments.isNotEmpty ? comments.length : (post['comment_count'] ?? 0);
    final imageUrl = post['image_url'];
    final myReaction = post['my_reaction'] as String?;
    final totalReactions = (post['total_reactions'] as int?) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4F0E5))),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_MAColors.green, Color(0xFF4CAF50)]), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Text(authorName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                              child: Text(authorRole.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: _MAColors.green)),
                            ),
                          ]),
                          Text(_timeAgo(post['created_at']), style: const TextStyle(fontSize: 9.5, color: _MAColors.sub)),
                        ],
                      ),
                    ),
                    if (type.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: _tagBg[type] ?? const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20)),
                        child: Text(type.toUpperCase(), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: _tagColor[type] ?? const Color(0xFF888888))),
                      ),
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('${post['title'] ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _MAColors.dark))),
              const SizedBox(height: 6),
              if (preview.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(preview, style: const TextStyle(fontSize: 12.5, color: Color(0xFF444444), height: 1.6)),
                ),
              // ── Image — "fit" na parang Facebook: buong picture makikita ──
              if (imageUrl != null)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 360),
                  color: const Color(0xFFF5F5F5),
                  child: Image.network(imageUrl, width: double.infinity, fit: BoxFit.fitWidth, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  _ReactionButton(myReaction: myReaction, totalReactions: totalReactions, reactions: post['reactions'] as List<dynamic>?, onReact: onReact, compact: true),
                  const Spacer(),
                  const Icon(Icons.mode_comment_outlined, size: 13, color: Color(0xFF888888)),
                  const SizedBox(width: 5),
                  Text('$commentCount', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
                  const SizedBox(width: 10),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Full detail "pop-up" (modal bottom sheet) — buong post + comments ─────
class _PostDetailSheet extends StatefulWidget {
  final dynamic post;
  final VoidCallback onCommentAdded;
  final void Function(String type) onReact;
  const _PostDetailSheet({required this.post, required this.onCommentAdded, required this.onReact});

  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
  late List<dynamic> _comments;
  final _commentCtrl = TextEditingController();
  bool _sending = false;
  String? _myReaction;
  int _totalReactions = 0;

  @override
  void initState() {
    super.initState();
    _comments = List.from((widget.post['comments'] as List?) ?? []);
    _myReaction = widget.post['my_reaction'] as String?;
    _totalReactions = (widget.post['total_reactions'] as int?) ?? 0;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentCtrl.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final newComment = await AnnouncementsService.addComment(widget.post['id'], _commentCtrl.text.trim());
      setState(() {
        _comments = [..._comments, newComment];
        _commentCtrl.clear();
      });
      widget.onCommentAdded();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _handleReactLocal(String type) {
    // Optimistic update habang tinatawag yung parent's onReact (na siyang
    // tumatawag sa aktwal na API at nag-a-update ng lokal na list).
    setState(() {
      if (_myReaction == type) {
        _myReaction = null;
        _totalReactions = (_totalReactions - 1).clamp(0, 999999);
      } else if (_myReaction == null) {
        _myReaction = type;
        _totalReactions += 1;
      } else {
        _myReaction = type; // palit lang, hindi nagdadagdag sa total
      }
    });
    widget.onReact(type);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final auth = context.watch<AuthProvider>();
    final currentInitial = (auth.name ?? auth.username ?? 'M').isNotEmpty ? (auth.name ?? auth.username ?? 'M')[0].toUpperCase() : 'M';
    final bodyText = '${post['body'] ?? post['caption'] ?? post['content'] ?? ''}';
    final authorName = '${post['posted_by_name'] ?? 'Admin'}';
    final authorRole = '${post['posted_by_role'] ?? 'admin'}';
    final type = '${post['type'] ?? ''}';
    final imageUrl = post['image_url'];

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(gradient: const LinearGradient(colors: [_MAColors.green, Color(0xFF4CAF50)]), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                                Text(authorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                                  child: Text(authorRole.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: _MAColors.green)),
                                ),
                              ]),
                              Text(_timeAgo(post['created_at']), style: const TextStyle(fontSize: 10, color: _MAColors.sub)),
                            ],
                          ),
                        ),
                        if (type.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(color: _tagBg[type] ?? const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20)),
                            child: Text(type.toUpperCase(), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: _tagColor[type] ?? const Color(0xFF888888))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('${post['title'] ?? ''}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _MAColors.dark)),
                    const SizedBox(height: 8),
                    if (bodyText.isNotEmpty) Text(bodyText, style: const TextStyle(fontSize: 13, color: Color(0xFF444444), height: 1.7)),
                    if (imageUrl != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          color: const Color(0xFFF5F5F5),
                          child: Image.network(imageUrl, width: double.infinity, fit: BoxFit.fitWidth, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // ── Reaction bar ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)), bottom: BorderSide(color: Color(0xFFF0F0F0)))),
                      child: _ReactionButton(myReaction: _myReaction, totalReactions: _totalReactions, reactions: widget.post['reactions'] as List<dynamic>?, onReact: _handleReactLocal),
                    ),
                    const SizedBox(height: 10),

                    Text('Comments (${_comments.length})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                    const SizedBox(height: 10),
                    if (_comments.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: Text('No comments yet. Be the first!', style: TextStyle(fontSize: 11.5, color: Color(0xFFCCCCCC), fontStyle: FontStyle.italic))))
                    else
                      ..._comments.map((c) {
                        final cName = '${c['posted_by_name'] ?? c['author'] ?? 'U'}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(radius: 15, backgroundColor: const Color(0xFFE8F5E9), child: Text(cName.isNotEmpty ? cName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 11, color: _MAColors.green, fontWeight: FontWeight.w700))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8F0E8))),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(cName, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF333333))),
                                        if (c['posted_by_role'] != null) Padding(padding: const EdgeInsets.only(left: 6), child: Text('${c['posted_by_role']}', style: const TextStyle(fontSize: 9, color: _MAColors.sub))),
                                        const Spacer(),
                                        Text(_timeAgo(c['created_at']), style: const TextStyle(fontSize: 9, color: _MAColors.sub)),
                                      ]),
                                      const SizedBox(height: 3),
                                      Text('${c['body'] ?? c['text'] ?? ''}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF444444), height: 1.4)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).viewInsets.bottom + 10),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
              child: Row(children: [
                CircleAvatar(radius: 15, backgroundColor: _MAColors.green, child: Text(currentInitial, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700))),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    onSubmitted: (_) => _submitComment(),
                    decoration: InputDecoration(hintText: 'Write a comment...', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE0E8E0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE0E8E0)))),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _MAColors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                  onPressed: _sending ? null : _submitComment,
                  child: _sending ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ],
        );
      },
    );
  }
}