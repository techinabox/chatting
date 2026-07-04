import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static Future<void> initialize() async {
    bool isDotEnvLoaded = false;
    try {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: ".env");
        isDotEnvLoaded = true;
      } else {
        isDotEnvLoaded = true;
      }
    } catch (e) {
      // Ignored: missing .env will fallback to String.fromEnvironment
    }

    final supabaseUrl = isDotEnvLoaded
        ? (dotenv.env['SUPABASE_URL'] ??
              const String.fromEnvironment('SUPABASE_URL'))
        : const String.fromEnvironment('SUPABASE_URL');

    final supabaseAnonKey = isDotEnvLoaded
        ? (dotenv.env['SUPABASE_ANON_KEY'] ??
              const String.fromEnvironment('SUPABASE_ANON_KEY'))
        : const String.fromEnvironment('SUPABASE_ANON_KEY');

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
}
