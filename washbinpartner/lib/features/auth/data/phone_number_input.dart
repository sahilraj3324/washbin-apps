/// Washbin operates in India, so numbers are entered as ten local digits and
/// this dial code is added before anything is sent to Firebase.
const washbinDialCode = '+91';
const washbinLocalNumberLength = 10;

/// Builds the E.164 form Firebase requires, e.g. `+919876543210`.
String toE164(String localDigits) =>
    '$washbinDialCode${localDigits.replaceAll(RegExp(r'\D'), '')}';

/// Renders a stored number for display, e.g. `+91 98765 43210`.
String formatForDisplay(String e164) {
  if (!e164.startsWith(washbinDialCode)) {
    return e164;
  }

  final local = e164.substring(washbinDialCode.length);
  if (local.length != washbinLocalNumberLength) {
    return e164;
  }

  return '$washbinDialCode ${local.substring(0, 5)} ${local.substring(5)}';
}
