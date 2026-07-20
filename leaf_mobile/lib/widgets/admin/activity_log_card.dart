import 'package:flutter/material.dart';

const Map<String, Color> _kActivityDotColors = {
  'payment':     Color(0xFF4CAF50),
  'application': Color(0xFF1565C0),
  'pending':     Color(0xFFF57C00),
  'register':    Color(0xFF4CAF50),
  'declined':    Color(0xFFE53935),
};

class ActivityLogCard extends StatelessWidget {
  final List<dynamic> log;
  final bool loading;

  const ActivityLogCard({super.key, required this.log, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDEEDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Activity Log',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B3A1B))),
          const SizedBox(height: 2),
          const Text('Latest system events', style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (log.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No recent activity yet.', style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: log.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F5F0)),
                itemBuilder: (context, i) {
                  final item = log[i];
                  final type = (item['type'] ?? '').toString();
                  final color = _kActivityDotColors[type] ?? const Color(0xFFAAAAAA);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 7, height: 7,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['text'] ?? ''}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF333333), fontWeight: FontWeight.w500, height: 1.45),
                              ),
                              const SizedBox(height: 2),
                              Text('${item['time'] ?? ''}', style: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}