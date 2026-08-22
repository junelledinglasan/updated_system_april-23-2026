// lib/widgets/ph_address_picker.dart
// Cascading Region → Province → City/Municipality → Barangay + Street,
// katumbas ng PSGC auto-complete na dinagdag sa web's RegisterModal.

import 'package:flutter/material.dart';
import '../services/psgc_service.dart';

class _PHColors {
  static const green  = Color(0xFF2E7D32);
  static const border = Color(0xFFE0E0E0);
  static const label  = Color(0xFFAAAAAA);
  static const red    = Color(0xFFE53935);
}

class PhAddressPicker extends StatefulWidget {
  final void Function(String fullAddress) onAddressChanged;
  final String? errorRegion;
  const PhAddressPicker({super.key, required this.onAddressChanged, this.errorRegion});

  @override
  State<PhAddressPicker> createState() => _PhAddressPickerState();
}

class _PhAddressPickerState extends State<PhAddressPicker> {
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];

  Map<String, dynamic>? _selRegion;
  Map<String, dynamic>? _selProvince;
  Map<String, dynamic>? _selCity;
  Map<String, dynamic>? _selBarangay;
  final _streetCtrl = TextEditingController();

  bool _loadingRegions = true;
  bool _loadingProvinces = false;
  bool _loadingCities = false;
  bool _loadingBarangays = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _streetCtrl.addListener(_emitAddress);
  }

  @override
  void dispose() {
    _streetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    setState(() => _loadingRegions = true);
    final regions = await PsgcService.getRegions();
    if (mounted) setState(() { _regions = regions; _loadingRegions = false; });
  }

  Future<void> _onRegionSelected(Map<String, dynamic>? r) async {
    setState(() {
      _selRegion = r;
      _selProvince = null; _selCity = null; _selBarangay = null;
      _provinces = []; _cities = []; _barangays = [];
    });
    _emitAddress();
    if (r == null) return;
    setState(() => _loadingProvinces = true);
    final provinces = await PsgcService.getProvinces('${r['code']}');
    if (mounted) setState(() { _provinces = provinces; _loadingProvinces = false; });
  }

  Future<void> _onProvinceSelected(Map<String, dynamic>? p) async {
    setState(() {
      _selProvince = p;
      _selCity = null; _selBarangay = null;
      _cities = []; _barangays = [];
    });
    _emitAddress();
    if (p == null) return;
    setState(() => _loadingCities = true);
    final cities = await PsgcService.getCities('${p['code']}');
    if (mounted) setState(() { _cities = cities; _loadingCities = false; });
  }

  Future<void> _onCitySelected(Map<String, dynamic>? c) async {
    setState(() {
      _selCity = c;
      _selBarangay = null;
      _barangays = [];
    });
    _emitAddress();
    if (c == null) return;
    setState(() => _loadingBarangays = true);
    final brgys = await PsgcService.getBarangays('${c['code']}');
    if (mounted) setState(() { _barangays = brgys; _loadingBarangays = false; });
  }

  void _onBarangaySelected(Map<String, dynamic>? b) {
    setState(() => _selBarangay = b);
    _emitAddress();
  }

  void _emitAddress() {
    final parts = [
      _streetCtrl.text.trim(),
      if (_selBarangay != null) 'Brgy. ${_selBarangay!['name']}',
      if (_selCity != null) '${_selCity!['name']}',
      if (_selProvince != null) '${_selProvince!['name']}',
      if (_selRegion != null) '${_selRegion!['name']}',
    ].where((p) => p.isNotEmpty).toList();
    widget.onAddressChanged(parts.join(', '));
  }

  InputDecoration _dec({bool loading = false, String? error}) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFAFCF8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        suffixIcon: loading ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))) : null,
        errorText: error,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _PHColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: error != null ? _PHColors.red : _PHColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _PHColors.green, width: 1.5)),
      );

  Widget _dropdown<T>({required String label, required bool required, required List<Map<String, dynamic>> items, required Map<String, dynamic>? value, required void Function(Map<String, dynamic>?) onChanged, bool loading = false, bool enabled = true, String? error}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(text: label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _PHColors.label), children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: _PHColors.red))])),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: value != null ? '${value['code']}' : null,
          items: items.map((it) => DropdownMenuItem(value: '${it['code']}', child: Text('${it['name']}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: !enabled || loading ? null : (code) => onChanged(items.firstWhere((it) => '${it['code']}' == code, orElse: () => {})),
          decoration: _dec(loading: loading, error: error),
          hint: Text(enabled ? 'Select...' : '—', style: const TextStyle(fontSize: 11.5, color: Color(0xFFBBBBBB))),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullPreview = [
      _streetCtrl.text.trim(),
      if (_selBarangay != null) 'Brgy. ${_selBarangay!['name']}',
      if (_selCity != null) '${_selCity!['name']}',
      if (_selProvince != null) '${_selProvince!['name']}',
      if (_selRegion != null) '${_selRegion!['name']}',
    ].where((p) => p.isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _dropdown(label: 'Region', required: true, items: _regions, value: _selRegion, onChanged: _onRegionSelected, loading: _loadingRegions, error: widget.errorRegion)),
          const SizedBox(width: 10),
          Expanded(child: _dropdown(label: 'Province', required: true, items: _provinces, value: _selProvince, onChanged: _onProvinceSelected, loading: _loadingProvinces, enabled: _selRegion != null)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _dropdown(label: 'City / Municipality', required: true, items: _cities, value: _selCity, onChanged: _onCitySelected, loading: _loadingCities, enabled: _selProvince != null)),
          const SizedBox(width: 10),
          Expanded(child: _dropdown(label: 'Barangay', required: true, items: _barangays, value: _selBarangay, onChanged: _onBarangaySelected, loading: _loadingBarangays, enabled: _selCity != null)),
        ]),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(TextSpan(text: 'House No. / Street / Sitio', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _PHColors.label), children: const [TextSpan(text: ' (optional)', style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA), fontStyle: FontStyle.italic))])),
            const SizedBox(height: 4),
            TextField(controller: _streetCtrl, style: const TextStyle(fontSize: 12.5), decoration: _dec()),
          ],
        ),
        if (fullPreview.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(8)),
            child: Text('📍 $fullPreview', style: const TextStyle(fontSize: 11, color: _PHColors.green, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}