import 'package:flutter/material.dart';
import '../../services/loans_service.dart';

class _CalColors {
  static const cardBorder = Color(0xFFDDEEDD);
  static const title      = Color(0xFF1B3A1B);
  static const sub        = Color(0xFFAAAAAA);
  static const today      = Color(0xFF2E7D32);
  static const hasEvent   = Color(0xFFC8E6C9);
  static const hasEventTx = Color(0xFF1B5E20);
  static const overdue    = Color(0xFFFCE4EC);
  static const overdueTx  = Color(0xFFC62828);
  static const dayIdle    = Color(0xFF555555);
  static const otherMonth = Color(0xFFDDDDDD);
}

const List<String> _kMonths = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December'
];

class CollectionCalendarCard extends StatefulWidget {
  const CollectionCalendarCard({super.key});

  @override
  State<CollectionCalendarCard> createState() => _CollectionCalendarCardState();
}

class _CollectionCalendarCardState extends State<CollectionCalendarCard> {
  late int _year;
  late int _month; // 0-based, kagaya ng JS Date
  Map<String, dynamic> _dueDates = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month - 1;
    _loadDueDates();
  }

  Future<void> _loadDueDates() async {
    setState(() => _loading = true);
    try {
      final mm = (_month + 1).toString().padLeft(2, '0');
      final data = await LoansService.getDueDates(month: '$_year-$mm');
      setState(() => _dueDates = Map<String, dynamic>.from(data));
    } catch (_) {
      setState(() => _dueDates = {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prev() {
    setState(() {
      if (_month == 0) { _month = 11; _year--; } else { _month--; }
    });
    _loadDueDates();
  }

  void _next() {
    setState(() {
      if (_month == 11) { _month = 0; _year++; } else { _month++; }
    });
    _loadDueDates();
  }

  void _onDayTap(int day) {
    final mm = (_month + 1).toString().padLeft(2, '0');
    final dd = day.toString().padLeft(2, '0');
    final key = '$_year-$mm-$dd';
    final members = (_dueDates[key] as List?) ?? [];
    if (members.isEmpty) return;
    _showDueDateModal(key, members);
  }

  void _showDueDateModal(String dateKey, List members) {
    final date = DateTime.parse(dateKey);
    const weekdays = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final formatted = '${weekdays[date.weekday - 1]}, ${_kMonths[date.month - 1]} ${date.day}, ${date.year}';
    double total = 0;
    for (final m in members) {
      total += double.tryParse('${m['monthly_due']}') ?? 0;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.event, size: 16, color: _CalColors.title),
                            SizedBox(width: 6),
                            Text('Collection Due', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(formatted, style: const TextStyle(fontSize: 12, color: _CalColors.sub)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final m = members[i];
                  final isOverdue = m['status'] == 'Overdue';
                  final name = (m['member_name'] ?? 'M').toString();
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isOverdue ? const Color(0xFFFFF8F8) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isOverdue ? const Color(0xFFFFCDD2) : const Color(0xFFE8F5E9)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isOverdue ? _CalColors.overdueTx : _CalColors.today,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'M',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '${m['member_id'] ?? ''} · ${m['loan_type'] ?? ''}',
                                style: const TextStyle(fontSize: 11, color: _CalColors.sub),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${(double.tryParse('${m['monthly_due']}') ?? 0).toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _CalColors.today),
                            ),
                            const Text('monthly due', style: TextStyle(fontSize: 9, color: _CalColors.sub)),
                            if (isOverdue)
                              const Text('OVERDUE',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _CalColors.overdueTx)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total: ₱${total.toStringAsFixed(0)} from ${members.length} member${members.length != 1 ? "s" : ""}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF555555)),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _CalColors.today,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstWeekday = DateTime(_year, _month + 1, 1).weekday % 7; // 0=Sun
    final totalDays = DateTime(_year, _month + 2, 0).day;
    final prevMonthDays = DateTime(_year, _month + 1, 0).day;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CalColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Collection Calendar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _CalColors.title)),
              ),
              Row(
                children: [
                  _LegendDot(color: _CalColors.today, label: 'Today'),
                  const SizedBox(width: 10),
                  _LegendDot(color: _CalColors.hasEvent, label: 'Due Date'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${_kMonths[_month]} $_year', style: const TextStyle(fontSize: 10, color: _CalColors.sub)),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavButton(icon: Icons.chevron_left, onTap: _prev),
              Text('${_kMonths[_month]} $_year', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _CalColors.title)),
              _NavButton(icon: Icons.chevron_right, onTap: _next),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _CalColors.sub)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 2),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday + totalDays,
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                final d = prevMonthDays - firstWeekday + 1 + index;
                return Center(
                  child: Text('$d', style: const TextStyle(fontSize: 10, color: _CalColors.otherMonth)),
                );
              }
              final day = index - firstWeekday + 1;
              final mm = (_month + 1).toString().padLeft(2, '0');
              final dd = day.toString().padLeft(2, '0');
              final key = '$_year-$mm-$dd';
              final dueList = (_dueDates[key] as List?) ?? [];
              final isToday = day == now.day && _month == now.month - 1 && _year == now.year;
              final hasOverdue = dueList.any((m) => m['status'] == 'Overdue');
              final hasDue = dueList.isNotEmpty;

              Color? bg;
              Color txColor = _CalColors.dayIdle;
              FontWeight weight = FontWeight.w500;
              if (isToday) { bg = _CalColors.today; txColor = Colors.white; weight = FontWeight.w700; }
              else if (hasOverdue) { bg = _CalColors.overdue; txColor = _CalColors.overdueTx; weight = FontWeight.w700; }
              else if (hasDue) { bg = _CalColors.hasEvent; txColor = _CalColors.hasEventTx; weight = FontWeight.w700; }

              return GestureDetector(
                onTap: hasDue ? () => _onDayTap(day) : null,
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text('$day', style: TextStyle(fontSize: 10, color: txColor, fontWeight: weight)),
                      if (hasDue)
                        Positioned(
                          top: 1, right: 1,
                          child: Container(
                            width: 12, height: 12,
                            decoration: BoxDecoration(
                              color: hasOverdue ? _CalColors.overdueTx : _CalColors.today,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text('${dueList.length}',
                                  style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: Text('Loading due dates...', style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFC8E6C9)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF2E7D32)),
        ),
      ),
    );
  }
}