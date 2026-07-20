import 'package:flutter/material.dart';

class BlockchainLedgerCard extends StatelessWidget {
  final List<dynamic> data;
  final bool loading;
  final void Function(dynamic row)? onPdfTap;

  const BlockchainLedgerCard({super.key, required this.data, this.loading = false, this.onPdfTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1923),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 15, color: Color(0xFFE8F5E9)),
              const SizedBox(width: 6),
              const Text('Real-time Blockchain Ledger',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE8F5E9))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x4069F0AE)),
                ),
                child: const Text('AUDIT',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF69F0AE), letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF69F0AE))),
            )
          else if (data.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No transactions yet.', style: TextStyle(color: Color(0x66FFFFFF), fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF131F28)),
              itemBuilder: (context, i) {
                final row = data[i];
                final amount = double.tryParse('${row['amount']}') ?? 0;
                final hash = '${row['hash'] ?? ''}';
                final shortHash = hash.length > 16 ? '${hash.substring(0, 8)}…${hash.substring(hash.length - 6)}' : hash;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${row['paid_at'] ?? ''}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF3D5A6A))),
                                const SizedBox(width: 8),
                                Text('${row['member_id'] ?? ''}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF7A8FA0), fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              shortHash,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF3D5A6A),
                                fontFamily: 'monospace',
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₱${amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF69F0AE)),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onPdfTap != null ? () => onPdfTap!(row) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC62828),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('PDF',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}