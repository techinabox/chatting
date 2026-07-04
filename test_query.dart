import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://hkytnedaxvsleychdowg.supabase.co',
    'sb_publishable_mkH7Qw2KEHVcH_wAIa3QJA_-dXqRjo3',
  );
  final res = await supabase.from('room_participants').select('*');
  print('Total participants: ${res.length}');
  for (var row in res) {
    print(
      'Room: ${row['room_id']}, User: ${row['user_id']}, Name: ${row['participant_name']}',
    );
  }
}
