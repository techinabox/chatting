import 'package:flutter_test/flutter_test.dart';
import 'package:ephemeral_chat/utils/invite_code_generator.dart';

void main() {
  test('Generates 20+ char alphanumeric code', () {
    final code = InviteCodeGenerator.generateSecureCode(20);
    expect(code.length, greaterThanOrEqualTo(20));
    expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(code), isTrue);
  });

  test('Throws ArgumentError if length is less than 20', () {
    expect(() => InviteCodeGenerator.generateSecureCode(19), throwsArgumentError);
    expect(() => InviteCodeGenerator.generateSecureCode(0), throwsArgumentError);
    expect(() => InviteCodeGenerator.generateSecureCode(-1), throwsArgumentError);
  });
}
