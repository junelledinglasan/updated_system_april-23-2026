// lib/services/supabase_storage_service.dart
// Direktang REST call papunta sa Supabase Storage (walang kailangang
// supabase_flutter package) — katumbas ng web's
// `supabase.storage.from("member-documents").upload(...)`.

import 'package:http/http.dart' as http;
import '../utils/supabase_config.dart';

class SupabaseStorageService {
  /// Nag-a-upload ng image bytes papunta sa Supabase Storage, nagbabalik
  /// ng public URL — o empty string kung nabigo. Ang `folder` ay
  /// nag-iiba depende sa gamit (hal. 'gcash-proofs', 'valid-ids').
  static Future<String> uploadFile(List<int> bytes, String filename, {String folder = 'uploads', String contentType = 'image/jpeg'}) async {
    if (SupabaseConfig.url.startsWith('PALITAN_MO')) {
      // Hindi pa na-configure yung Supabase credentials — wag munang
      // subukan mag-upload, para hindi mag-crash.
      return '';
    }
    try {
      final path = '$folder/$filename';
      final uploadUri = Uri.parse('${SupabaseConfig.url}/storage/v1/object/${SupabaseConfig.bucket}/$path');
      final res = await http.post(
        uploadUri,
        headers: {
          'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
          'apikey': SupabaseConfig.anonKey,
          'Content-Type': contentType,
        },
        body: bytes,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return '${SupabaseConfig.url}/storage/v1/object/public/${SupabaseConfig.bucket}/$path';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  // Backward-compatible alias — ginagamit pa rin ito sa GCash payment screen.
  static Future<String> uploadScreenshot(List<int> bytes, String filename) =>
      uploadFile(bytes, filename, folder: 'gcash-proofs');
}