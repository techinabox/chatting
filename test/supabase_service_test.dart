import 'package:flutter_test/flutter_test.dart';
import 'package:ephemeral_chat/services/supabase_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('SupabaseService initializes successfully', () async {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: '''
SUPABASE_URL=https://mock.supabase.co
SUPABASE_ANON_KEY=mock_anon_key
''');

    await SupabaseService.initialize();

    expect(Supabase.instance, isNotNull);
  });
}
