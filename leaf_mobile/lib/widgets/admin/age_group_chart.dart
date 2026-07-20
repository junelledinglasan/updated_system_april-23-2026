import 'package:flutter/material.dart';

int? _computeAge(String? birthDate) {
  if (birthDate == null || birthDate.isEmpty) return null;
  try {
    final bd = DateTime.parse(birthDate);
    final today = DateTime.now();
    int age = today.year - bd.year;
    if (today.month < bd.month || (today.month == bd.month && today.day < bd.day)) age--;
    return age;
  } catch (_) {
    return null;
  }
}

class AgeGroupChart extends StatelessWidget {
  final List<dynamic> members;
  const AgeGroupChart({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    final buckets = <String, int>{
      '18–25': 0, '26–35': 0, '36–45': 0,
      '46–55': 0, '56–65': 0, '65+': 0, 'Unknown': 0,
    };
    for (final m in members) {
      final age = _computeAge(m['birth_date']);
      if (age == null || age < 18) {
        buckets['Unknown'] = buckets['Unknown']! + 1;
        continue;
      }
      if (age <= 25) buckets['18–25'] = buckets['18–25']! + 1;
      else if (age <= 35) buckets['26–35'] = buckets['26–35']! + 1;
      else if (age <= 45) buckets['36–45'] = buckets['36–45']! + 1;
      else if (age <= 55) buckets['46–55'] = buckets['46–55']! + 1;
      else if (age <= 65) buckets['56–65'] = buckets['56–65']! + 1;
      else buckets['65+'] = buckets['65+']! + 1;
    }

    const colors = {
      '18–25': Color(0xFF42A5F5), '26–35': Color(0xFF66BB6A), '36–45': Color(0xFFFFA726),
      '46–55': Color(0xFFAB47BC), '56–65': Color(0xFFEF5350), '65+': Color(0xFF26C6DA), 'Unknown': Color(0xFFBDBDBD),
    };

    final max = buckets.values.fold<int>(1, (a, b) => a > b ? a : b);
    final total = members.length == 0 ? 1 : members.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8F5E9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Members by Age Group', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20))),
          const SizedBox(height: 12),
          ...buckets.entries.map((entry) {
            final ratio = entry.value == 0 ? 0.0 : (entry.value / max).clamp(0.04, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(width: 48, child: Text(entry.key, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF555555)))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(height: 16, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20))),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(height: 16, decoration: BoxDecoration(color: colors[entry.key], borderRadius: BorderRadius.circular(20))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text.rich(
                      TextSpan(text: '${entry.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF333333)), children: [
                        if (entry.value > 0)
                          TextSpan(text: ' (${(entry.value / total * 100).round()}%)', style: const TextStyle(fontSize: 9, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w400)),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}