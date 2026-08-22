import 'package:flutter/material.dart';
import '../../services/members_service.dart';

class _PAColors {
  static const green  = Color(0xFF2E7D32);
  static const dark   = Color(0xFF1B5E20);
  static const sub    = Color(0xFF888888);
  static const orange = Color(0xFFE65100);
}

class PendingApplicationScreen extends StatefulWidget {
  final dynamic app;
  const PendingApplicationScreen({super.key, required this.app});

  @override
  State<PendingApplicationScreen> createState() => _PendingApplicationScreenState();
}

class _PendingApplicationScreenState extends State<PendingApplicationScreen> {
  final _shareCtrl = TextEditingController(text: '4000');
  bool _converting = false;

  @override
  void dispose() {
    _shareCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConvert() async {
    setState(() => _converting = true);
    try {
      final sharePaid = double.tryParse(_shareCtrl.text) ?? 0;
      final result = await MembersService.convertOnlineApp(widget.app['id'], {'share_capital': sharePaid});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ ${widget.app['first_name']} ${widget.app['last_name']} is now an official member! ID: ${result['member_id'] ?? ''}'),
            backgroundColor: _PAColors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to convert member.'), backgroundColor: Color(0xFFC62828)),
        );
      }
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final fullname = '${app['first_name'] ?? ''} ${app['last_name'] ?? ''}';
    final sharePaid = double.tryParse(_shareCtrl.text) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _PAColors.dark,
        elevation: 0.5,
        title: const Text('Pending Application', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _PAColors.dark)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4F0E5))),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _PAColors.orange,
                    child: Text(fullname.isNotEmpty ? fullname[0].toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fullname, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _PAColors.dark)),
                        Text('${app['app_id'] ?? ''}', style: const TextStyle(fontSize: 10, color: _PAColors.sub, fontFamily: 'monospace')),
                        Text('Submitted ${'${app['created_at'] ?? ''}'.split('T').first}', style: const TextStyle(fontSize: 10.5, color: _PAColors.sub)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFFE0B2))),
                    child: const Text('Pending', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _PAColors.orange)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFE0B2))),
              child: const Text(
                'This applicant has been approved online. They need to visit the office to complete the process.',
                style: TextStyle(fontSize: 12, color: _PAColors.orange, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),

            // ── Share paid input ────────────────────────────────────────
            const Text('Amount Paid for Membership (₱) *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _PAColors.sub)),
            const SizedBox(height: 4),
            TextField(
              controller: _shareCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixText: '₱ ',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
              ),
            ),
            if (sharePaid > 0) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'Share Capital = ₱${(sharePaid * 2).toStringAsFixed(0)} · Max Loanable = ₱${(sharePaid * 2).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 10.5, color: _PAColors.green, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 16),

            const Text('PERSONAL INFORMATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _PAColors.sub, letterSpacing: 0.6)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _InfoField('Middle Name', app['middle_name']),
                _InfoField('Birthdate', app['birth_date']),
                _InfoField('Place of Birth', app['place_of_birth']),
                _InfoField('Sex', app['sex']),
                _InfoField('Civil Status', app['civil_status']),
                _InfoField('TIN No.', app['tin_no']),
                _InfoField('SSS/GSIS No.', app['sss_gsis_no']),
                _InfoField('Educational Attainment', app['educational_attainment']),
                _InfoField('Contact No.', app['contact_number']),
                _InfoField('Email', app['email']),
                _InfoField('Occupation', app['occupation']),
                _InfoField('Monthly Income (₱)', app['income'] != null && '${app['income']}'.isNotEmpty ? '₱${double.tryParse('${app['income']}')?.toStringAsFixed(0) ?? app['income']}' : null),
                _InfoField('Classification', app['classification']),
                _InfoField('Religious/Social Affiliation', app['religious_social_affiliation']),
              ],
            ),
            const SizedBox(height: 10),
            _InfoField('Address', app['address'], full: true),

            if (('${app['spouse_name'] ?? ''}'.isNotEmpty) || ('${app['beneficiary_name'] ?? ''}'.isNotEmpty)) ...[
              const SizedBox(height: 18),
              const Text('SPOUSE & FAMILY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _PAColors.sub, letterSpacing: 0.6)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _InfoField('Spouse Name', app['spouse_name']),
                  _InfoField('Spouse Occupation', app['spouse_occupation']),
                  _InfoField('Spouse Income (₱)', app['spouse_income']),
                  _InfoField('No. of Dependants', app['no_of_dependants']),
                  _InfoField('Beneficiary', app['beneficiary_name']),
                  _InfoField('Relationship', app['beneficiary_relationship']),
                ],
              ),
              if ('${app['credit_references'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoField('Credit References', app['credit_references'], full: true),
              ],
            ],

            const SizedBox(height: 18),
            const Text('DOCUMENTS SUBMITTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _PAColors.sub, letterSpacing: 0.6)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _InfoField('Birth Certificate', app['birth_certificate'] == true ? '✅ Submitted' : '❌ Not submitted'),
                _InfoField('Marriage Certificate', app['marriage_certificate'] == true ? '✅ Submitted' : '❌ Not submitted'),
              ],
            ),

            if (('${app['id_front_url'] ?? ''}'.isNotEmpty) || ('${app['id_back_url'] ?? ''}'.isNotEmpty)) ...[
              const SizedBox(height: 18),
              const Text('VALID ID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _PAColors.sub, letterSpacing: 0.6)),
              const SizedBox(height: 8),
              Row(
                children: [
                  if ('${app['id_front_url'] ?? ''}'.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Front', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _PAColors.sub)),
                          const SizedBox(height: 6),
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(app['id_front_url'], height: 140, width: double.infinity, fit: BoxFit.cover)),
                        ],
                      ),
                    ),
                  if (('${app['id_front_url'] ?? ''}'.isNotEmpty) && ('${app['id_back_url'] ?? ''}'.isNotEmpty)) const SizedBox(width: 10),
                  if ('${app['id_back_url'] ?? ''}'.isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Back', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _PAColors.sub)),
                          const SizedBox(height: 6),
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(app['id_back_url'], height: 140, width: double.infinity, fit: BoxFit.cover)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _PAColors.green, foregroundColor: Colors.white),
                  onPressed: _converting ? null : _handleConvert,
                  child: _converting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('✓ Convert to Official Member'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool full;
  const _InfoField(this.label, this.value, {this.full = false});

  @override
  Widget build(BuildContext context) {
    final width = full ? double.infinity : (MediaQuery.of(context).size.width - 44) / 2;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _PAColors.sub, letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(value == null || '$value'.isEmpty ? '—' : '$value', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
        ],
      ),
    );
  }
}