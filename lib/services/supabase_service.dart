import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://hkytnedaxvsleychdowg.supabase.co',
      anonKey: 'sb_publishable_mkH7Qw2KEHVcH_wAIa3QJA_-dXqRjo3',
    );
  }
}
