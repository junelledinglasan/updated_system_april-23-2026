// lib/providers/language_provider.dart
//
// ── Language switcher (English/Filipino) para sa member app —
// katumbas ng web's LanguageContext.jsx. Naka-save sa
// SharedPreferences (survives app restart, hindi tulad ng
// PageCache na in-memory lang). ─────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../i18n/translations.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _storageKey = 'leaf_language';

  String _language = 'en';
  String get language => _language;

  bool _loaded = false;
  bool get loaded => _loaded;

  // ── Tinatawag ito minsan lang, sa app startup (hal. sa splash
  // screen o sa unang build ng root widget) — kinukuha ang naka-save
  // nang wika bago ipakita ang UI. ────────────────────────────────
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey);
      _language = saved == 'fil' ? 'fil' : 'en';
    } catch (_) {
      _language = 'en';
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, lang);
    } catch (_) {}
  }

  Future<void> toggleLanguage() async {
    await setLanguage(_language == 'en' ? 'fil' : 'en');
  }

  // ── t(key, vars) — kunin ang translation, palitan ang
  // {placeholders} gamit ang vars map. Kung walang laman sa
  // kasalukuyang wika, babalik sa English; kung wala rin doon,
  // ibabalik na lang ang key mismo (para hindi kailanman blangko
  // ang ipinapakita). ─────────────────────────────────────────────
  String t(String key, [Map<String, dynamic>? vars]) {
    final dict = translations[_language] ?? translations['en']!;
    String str = dict[key] ?? translations['en']![key] ?? key;
    if (vars != null) {
      vars.forEach((k, v) {
        str = str.replaceAll('{$k}', '$v');
      });
    }
    return str;
  }
}