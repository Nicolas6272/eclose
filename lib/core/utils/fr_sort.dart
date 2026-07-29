/// French-friendly string helpers (accent-insensitive compare / search).

/// Lowercases and strips common FR diacritics so "Échalote" sorts with "E".
String foldFr(String value) {
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final unit in lower.runes) {
    buffer.write(_foldRune(unit));
  }
  return buffer.toString();
}

String _foldRune(int unit) {
  return switch (unit) {
    0xE0 || 0xE1 || 0xE2 || 0xE3 || 0xE4 || 0xE5 => 'a', // àáâãäå
    0xE7 => 'c', // ç
    0xE8 || 0xE9 || 0xEA || 0xEB => 'e', // èéêë
    0xEC || 0xED || 0xEE || 0xEF => 'i', // ìíîï
    0xF1 => 'n', // ñ
    0xF2 || 0xF3 || 0xF4 || 0xF5 || 0xF6 => 'o', // òóôõö
    0xF9 || 0xFA || 0xFB || 0xFC => 'u', // ùúûü
    0xFD || 0xFF => 'y', // ýÿ
    0xE6 => 'ae', // æ
    0x153 => 'oe', // œ
    _ => String.fromCharCode(unit),
  };
}

int compareFr(String a, String b) => foldFr(a).compareTo(foldFr(b));
