// lib/providers/member_provider.dart
// Katumbas ng web's MemberLayout context (member, isOfficial, notifCount) —
// ChangeNotifier na hawak ang official/non-official status ng member,
// ginagamit ng lahat ng member screens (Dashboard, My Loans, atbp.)

import 'package:flutter/material.dart';
import '../services/members_service.dart';

class MemberProvider extends ChangeNotifier {
  bool _loading = true;
  bool _isOfficial = false;
  Map<String, dynamic>? _profile;
  String? _appStatus;
  int _notifCount = 0;
  Future<void>? _inFlightLoad; // BAGO: iwas duplicate/sabay-sabay na load() calls

  bool get loading => _loading;
  bool get isOfficial => _isOfficial;
  Map<String, dynamic>? get profile => _profile;
  String? get appStatus => _appStatus;
  int get notifCount => _notifCount;

  String get name => _profile?['fullname'] ?? _profile?['first_name'] ?? 'Member';
  String get memberId => _profile?['member_id'] ?? '—';
  String get initials => (_profile?['first_name'] ?? name).toString().isNotEmpty
      ? (_profile?['first_name'] ?? name).toString()[0].toUpperCase()
      : 'M';

  Future<void> load() {
    // Kung may kasalukuyang tumatakbo nang load(), huwag nang bumuo ng
    // bago — ibalik na lang ang PAREHONG Future na 'yon. Dati kasi, kapag
    // maraming screens ang bigla-biglang na-mount (mabilis na navigation),
    // bawat isa ay tumatawag ng sarili nilang load(), na sanhi ng
    // paulit-ulit/sabay-sabay na 404 requests sa parehong endpoint.
    if (_inFlightLoad != null) return _inFlightLoad!;
    _inFlightLoad = _doLoad();
    return _inFlightLoad!;
  }

  Future<void> _doLoad() async {
    _loading = true;
    notifyListeners();
    try {
      // Subukan munang kunin yung official member profile
      final profile = await MembersService.getMyProfile();
      _profile = profile;
      _isOfficial = true;
    } catch (_) {
      // Fallback: i-check yung status ng online application
      try {
        final app = await MembersService.getMyOnlineApp();
        _isOfficial = false;
        _appStatus = app['application_status'];
      } catch (_) {
        _isOfficial = false;
        _appStatus = null;
      }
    } finally {
      _loading = false;
      _inFlightLoad = null;
      notifyListeners();
    }
  }

  void setNotifCount(int count) {
    _notifCount = count;
    notifyListeners();
  }

  // ── BAGO: I-clear lahat ng data pag nag-logout — dati kasi nananatili
  // ang lumang profile ng NAKARAANG account, kaya kapag naka-login ang
  // BAGONG account, "stale" pa rin ang lumang datos hangga't hindi
  // pinilit i-reload (dahil `loading` ay `false` na mula sa dating
  // successful load, kaya hindi na natrigger ulit ang `.load()`).
  void reset() {
    _loading = true;
    _isOfficial = false;
    _profile = null;
    _appStatus = null;
    _notifCount = 0;
    _inFlightLoad = null;
    notifyListeners();
  }
}