/// Turns text into the form compared by the global search and the
/// per-column filters.
typedef TextNormalizer = String Function(String text);

/// Built-in [TextNormalizer]s.
///
/// [normalize] (the default of `FilterItemsUseCase`) is case-insensitive and
/// folds the spelling variants that make Arabic search frustrating:
///
/// * diacritics (tashkeel), Quranic marks and tatweel are removed:
///   `مُحَمَّد` → `محمد`, `كتـــاب` → `كتاب`;
/// * alef forms are unified: `أ إ آ ٱ` → `ا`;
/// * `ة` → `ه`, `ى` → `ي`, `ؤ` → `و`, `ئ` → `ي`, Persian `ی` / `ک` → `ي` / `ك`;
/// * Arabic-Indic and Persian digits become ASCII digits (`١٢٣` → `123`),
///   with the Arabic decimal (`٫`) and thousands (`٬`) separators.
///
/// So `احمد` finds `أحمد`, `مدرسه` finds `مدرسة`, and `١٥٠٠` finds `1500`.
abstract final class TableTextNormalizer {
  /// Lower-cases and folds Arabic spelling variants and digits (see the class
  /// documentation).
  static String normalize(String text) {
    final lower = text.toLowerCase();
    if (!_hasArabic(lower)) return lower;
    final buffer = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final c = lower.codeUnitAt(i);
      final folded = _fold(c);
      if (folded == null) {
        buffer.writeCharCode(c);
      } else if (folded >= 0) {
        buffer.writeCharCode(folded);
      }
    }
    return buffer.toString();
  }

  /// Only lower-cases (no Arabic folding).
  static String caseInsensitive(String text) => text.toLowerCase();

  /// Converts Arabic-Indic / Persian digits and the Arabic decimal and
  /// thousands separators to ASCII, leaving everything else untouched.
  /// Used before parsing numbers and dates typed by the user.
  static String digitsToAscii(String text) {
    if (!_hasArabic(text)) return text;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      buffer.writeCharCode(_digit(c) ?? c);
    }
    return buffer.toString();
  }

  static bool _hasArabic(String text) {
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c >= 0x0610 && c <= 0x06FF) return true;
    }
    return false;
  }

  static int? _digit(int c) {
    if (c >= 0x0660 && c <= 0x0669) return 0x30 + c - 0x0660; // ٠-٩
    if (c >= 0x06F0 && c <= 0x06F9) return 0x30 + c - 0x06F0; // ۰-۹
    if (c == 0x066B) return 0x2E; // ٫ decimal separator → .
    if (c == 0x066C) return 0x2C; // ٬ thousands separator → ,
    return null;
  }

  /// The replacement of [c]: `null` keeps it, `-1` drops it.
  static int? _fold(int c) {
    if (c < 0x0610 || c > 0x06FF) return null;
    final isMark =
        (c >= 0x0610 && c <= 0x061A) || // honorific marks
        (c >= 0x064B && c <= 0x065F) || // tashkeel
        c == 0x0670 || // superscript alef
        (c >= 0x06D6 && c <= 0x06ED) || // Quranic annotation marks
        c == 0x0640; // tatweel
    if (isMark) return -1;
    switch (c) {
      case 0x0622 || 0x0623 || 0x0625 || 0x0671: // آ أ إ ٱ
        return 0x0627; // ا
      case 0x0629: // ة
        return 0x0647; // ه
      case 0x0649 || 0x06CC || 0x0626: // ى ی ئ
        return 0x064A; // ي
      case 0x0624: // ؤ
        return 0x0648; // و
      case 0x06A9: // ک
        return 0x0643; // ك
    }
    return _digit(c);
  }
}
