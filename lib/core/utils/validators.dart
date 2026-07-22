/// Form field validators, returning null when valid and a message otherwise —
/// the contract Flutter's [FormFieldValidator] expects.
///
/// Kept in one place so "enter a valid email" reads identically on sign-in and
/// registration.
abstract final class Validators {
  static final _emailRe = RegExp(r'^[\w.\-+]+@[\w\-]+\.[\w\-.]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address';
    if (!_emailRe.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter your password';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  /// For sign-in, where we don't want to hint at password rules.
  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your full name';
    if (v.length < 2) return 'Enter your full name';
    return null;
  }

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter a contact number';
    // Permissive: strip formatting, require 7–15 digits (E.164 range).
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'Passwords do not match';
    return null;
  }
}
