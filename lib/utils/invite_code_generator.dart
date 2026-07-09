import 'dart:math';

class InviteCodeGenerator {
  static const _adjectives = [
    'brave', 'calm', 'clever', 'eager', 'fast', 'happy', 'jolly', 'kind', 
    'lucky', 'proud', 'quiet', 'silly', 'swift', 'warm', 'wise', 'bold',
    'cool', 'deep', 'fair', 'good', 'huge', 'neat', 'rich', 'safe', 'true',
    'agile', 'alert', 'bright', 'clean', 'clear', 'crisp', 'dark', 'eager',
    'fierce', 'fresh', 'gentle', 'grand', 'great', 'hard', 'holy', 'keen',
    'light', 'lively', 'loyal', 'merry', 'noble', 'pure', 'quick', 'rare',
    'sharp', 'smart', 'solid', 'strong', 'sweet', 'tall', 'tough', 'vast'
  ];
  
  static const _nouns = [
    'apple', 'bear', 'bird', 'cat', 'dog', 'eagle', 'fox', 'frog', 'lion',
    'moon', 'owl', 'pear', 'pine', 'rose', 'star', 'sun', 'tree', 'wolf',
    'wood', 'fish', 'duck', 'deer', 'hawk', 'lake', 'river', 'cloud', 'wind',
    'storm', 'rain', 'snow', 'ice', 'fire', 'rock', 'stone', 'sand', 'dust',
    'gold', 'silver', 'iron', 'steel', 'glass', 'ship', 'boat', 'car', 'plane',
    'train', 'bike', 'road', 'path', 'trail', 'hill', 'mountain', 'valley',
    'ocean', 'sea', 'beach', 'coast', 'island', 'forest', 'jungle', 'desert'
  ];

  static const _verbs = [
    'jump', 'run', 'fly', 'swim', 'walk', 'sing', 'dance', 'play', 'read',
    'write', 'draw', 'paint', 'sleep', 'eat', 'drink', 'smile', 'laugh',
    'think', 'dream', 'look', 'listen', 'speak', 'hide', 'seek', 'find',
    'build', 'make', 'create', 'grow', 'plant', 'catch', 'throw', 'push',
    'pull', 'lift', 'drop', 'fall', 'rise', 'stand', 'sit', 'lie', 'wait',
    'stop', 'go', 'come', 'leave', 'stay', 'return', 'give', 'take', 'keep',
    'show', 'tell', 'ask', 'answer', 'help', 'work', 'rest', 'watch', 'feel'
  ];

  static String generatePassphrase() {
    final random = Random.secure();
    final adj = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    final verb = _verbs[random.nextInt(_verbs.length)];
    // Random 2-digit number (10-99)
    final num = random.nextInt(90) + 10;
    return '$adj-$noun-$verb-$num';
  }

  // Keep for backwards compatibility if needed, or remove.
  static String generateSecureCode(int length) {
    return generatePassphrase();
  }
}
