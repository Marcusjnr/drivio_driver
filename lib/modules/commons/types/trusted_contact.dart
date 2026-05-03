/// A driver-supplied emergency contact (≤3 per driver, enforced by
/// `_enforce_trusted_contacts_cap` trigger on the server). The `primary`
/// flag is mutually exclusive — see the partial-unique index
/// `trusted_contacts_one_primary_per_user`.
class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phoneE164,
    required this.isPrimary,
  });

  final String id;
  final String name;
  final String phoneE164;
  final bool isPrimary;

  /// Mask middle digits for display: `+234 801 •••• 3344`.
  String get maskedPhone {
    final String p = phoneE164;
    if (p.length < 8) return p;
    final String head = p.substring(0, p.length - 4);
    final String tail = p.substring(p.length - 4);
    // Replace the last 4 chars of the head (excluding the +) with bullets.
    final int maskFrom = head.length - 4;
    if (maskFrom <= 0) return '${head.substring(0, head.length ~/ 2)} •••• $tail';
    return '${head.substring(0, maskFrom)} •••• $tail';
  }

  TrustedContact copyWith({
    String? name,
    String? phoneE164,
    bool? isPrimary,
  }) {
    return TrustedContact(
      id: id,
      name: name ?? this.name,
      phoneE164: phoneE164 ?? this.phoneE164,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  factory TrustedContact.fromJson(Map<String, dynamic> json) {
    return TrustedContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneE164: json['phone_e164'] as String,
      isPrimary: (json['is_primary'] as bool?) ?? false,
    );
  }
}
