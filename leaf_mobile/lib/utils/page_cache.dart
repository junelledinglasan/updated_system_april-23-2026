// lib/utils/page_cache.dart
//
// ── Cache-first na pattern para sa member app pages — instant na
// ipinapakita ang huling nakitang datos habang tahimik na nagre-
// refresh sa likod, imbes na palaging nagpapakita ng loading spinner
// tuwing may bagong pag-navigate. Katumbas ito ng web's pageCache.js.
//
// MAHALAGA: static IN-MEMORY na Map ito (hindi SharedPreferences) —
// sinasadya, dahil ang SharedPreferences ay ASYNCHRONOUS mag-basa sa
// Flutter (may async gap bago available ang laman, kaya may mag-
// fli-flicker pa rin). Ang static in-memory Map ay SYNCHRONOUS —
// available agad sa unang frame, walang async gap, katumbas ng
// sessionStorage sa web (nabubuhay habang bukas ang app session,
// nawawala kapag talagang isinara/kina-kill ang app).
//
// Naka-scope ang bawat cache entry sa account (scopeKey) — kaya kahit
// magpalit ng account sa parehong app session, hindi makikita ng
// bagong account ang cached data ng nauna.

class PageCache {
  static final Map<String, dynamic> _store = {};

  static String _key(String pageKey, String? scopeKey) => '${pageKey}_${scopeKey ?? "anon"}';

  static T? get<T>(String pageKey, String? scopeKey) {
    final v = _store[_key(pageKey, scopeKey)];
    return v is T ? v : null;
  }

  static void set(String pageKey, String? scopeKey, dynamic data) {
    _store[_key(pageKey, scopeKey)] = data;
  }

  // ── Ginagamit sa logout — para talagang malinis lahat ng naka-cache
  // na datos ng dating account. ────────────────────────────────────
  static void clearAll() {
    _store.clear();
  }
}