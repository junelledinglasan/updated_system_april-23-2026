// lib/services/psgc_service.dart
// Philippine Standard Geographic Code API — katumbas ng ginamit sa web
// para sa Region → Province → City/Municipality → Barangay cascade.

import 'dart:convert';
import 'package:http/http.dart' as http;

class PsgcService {
  static const _base = 'https://psgc.gitlab.io/api';

  static Future<List<Map<String, dynamic>>> getRegions() => _get('$_base/regions/');

  static Future<List<Map<String, dynamic>>> getProvinces(String regionCode) =>
      _get('$_base/regions/$regionCode/provinces/');

  static Future<List<Map<String, dynamic>>> getCities(String provinceCode) =>
      _get('$_base/provinces/$provinceCode/cities-municipalities/');

  static Future<List<Map<String, dynamic>>> getBarangays(String cityCode) =>
      _get('$_base/cities-municipalities/$cityCode/barangays/');

  static Future<List<Map<String, dynamic>>> _get(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        final items = list.cast<Map<String, dynamic>>();
        items.sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
        return items;
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}