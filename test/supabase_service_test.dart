// test/supabase_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ephemeral_chat/services/supabase_service.dart';

void main() {
  test('SupabaseService initializes successfully', () async {
    final service = SupabaseService();
    expect(service, isNotNull);
  });
}
