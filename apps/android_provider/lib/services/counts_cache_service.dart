/// Simple cache for data counts computed by extraction_provider.
/// Shared between the UI (extraction_provider) and server (/counts endpoint).
class CountsCacheService {
  static final CountsCacheService _instance = CountsCacheService._();
  factory CountsCacheService() => _instance;
  CountsCacheService._();

  int? _phoneNumbersCount;
  bool _isComputing = false;

  /// Get cached phone numbers count (null if not yet computed)
  int? get phoneNumbersCount => _phoneNumbersCount;

  /// Check if currently computing
  bool get isComputing => _isComputing;

  /// Update the cached phone numbers count
  void setPhoneNumbersCount(int count) {
    _phoneNumbersCount = count;
    _isComputing = false;
  }

  /// Mark as computing
  void setComputing(bool value) {
    _isComputing = value;
  }

  /// Clear cache (e.g., when permissions change)
  void clear() {
    _phoneNumbersCount = null;
    _isComputing = false;
  }
}
