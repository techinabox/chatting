import 'dart:math';

class InviteCodeGenerator {
  static String generateSecureCode(int length) {
    if (length < 20) {
      throw ArgumentError('Length must be at least 20');
    }
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}
