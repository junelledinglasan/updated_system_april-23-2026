// lib/utils/supabase_config.dart
// Katumbas ng web's VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY (.env) —
// dito ilalagay yung parehong values para gumana ang direktang pag-upload
// ng GCash screenshot proof papunta sa Supabase Storage.
//
// SAAN HAHANAPIN: sa web project mo, buksan yung .env file (root ng
// frontend/leaf_app), hanapin yung:
//   VITE_SUPABASE_URL=https://xxxxx.supabase.co
//   VITE_SUPABASE_ANON_KEY=eyJhbGci...
// I-copy yung parehong values dito sa ibaba.

class SupabaseConfig {
  static const String url = ''; // hal. https://xxxxx.supabase.co
  static const String anonKey = '';
  static const String bucket = ''; // katulad ng ginamit sa web
}