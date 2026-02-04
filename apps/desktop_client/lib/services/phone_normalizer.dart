/// Service for normalizing phone numbers.
/// Korean numbers: digits only (e.g., "01012345678")
/// International numbers: E.164 format (e.g., "+15551234567")
class PhoneNormalizer {
  /// Normalize a phone number.
  /// Returns null for invalid or unrecognized formats.
  ///
  /// - Korean domestic numbers become digits-only (e.g., "010-1234-5678" -> "01012345678")
  /// - International numbers keep E.164 format (e.g., "+1-555-1234" -> "+15551234")
  /// - Korean numbers with +82 country code are converted to domestic format
  String? normalize(String rawNumber) {
    // Strip all non-digit characters except leading +
    final cleaned = rawNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.isEmpty) return null;

    // Already has country code (international)
    if (cleaned.startsWith('+')) {
      // Check if it's a Korean number with country code
      if (cleaned.startsWith('+82')) {
        // Convert +8210... to 010... (digits only for Korean)
        final withoutCountry = cleaned.substring(3);
        if (withoutCountry.startsWith('10')) {
          return '0$withoutCountry'; // +821012345678 -> 01012345678
        }
        // Other Korean numbers (landlines): 0 + rest
        return '0$withoutCountry';
      }
      // Non-Korean international: keep E.164 format
      return cleaned;
    }

    // Korean domestic mobile (010-xxxx-xxxx) - digits only
    if (cleaned.startsWith('010') && cleaned.length >= 10) {
      return cleaned; // Already digits only: 01012345678
    }

    // Korean domestic with area code (02-xxxx-xxxx, etc.) - digits only
    if (cleaned.startsWith('0') && cleaned.length >= 9) {
      return cleaned; // Keep as digits: 0212345678
    }

    // Unknown format - return as-is if reasonable length
    if (cleaned.length >= 7 && cleaned.length <= 15) {
      return cleaned;
    }

    return null; // Invalid or unrecognized format
  }

  /// Check if a normalized number is a Korean mobile number (010 prefix).
  /// Works with digits-only format.
  bool isKoreanMobile(String normalizedNumber) {
    return normalizedNumber.startsWith('010');
  }
}
